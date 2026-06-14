import Foundation
import os

private let logger = Logger(subsystem: "com.markstudios.OneOnOne", category: "TransportRouter")

/// Routes messages through the best available transport:
/// MultipeerConnectivity (local) preferred, CloudKit relay as fallback.
/// Queues messages when no transport is available for retry on reconnect.
@Observable
@MainActor
public final class TransportRouter {
    private static let pendingQueueKey = "com.markstudios.1on1.transportRouterPendingQueue"

    private let peerManager: PeerManager
    public var cloudRelay: CloudRelayManager? {
        didSet { bindCloudRelay() }
    }

    /// Time-ordered dedup buffer — evicts entries older than 5 minutes
    private var deliveredIDs: [(id: UUID, time: Date)] = []
    private static let dedupWindow: TimeInterval = 300

    /// Messages queued while offline, delivered on reconnect.
    /// Persisted so queued sends survive a relaunch.
    public private(set) var pendingQueue: [Message] = []

    public var onMessageReceived: (@MainActor (Message) -> Void)?
    public var onDeliveryStatusChanged: (@MainActor (UUID, DeliveryStatus) -> Void)?

    public init(peerManager: PeerManager) {
        self.peerManager = peerManager
        self.pendingQueue = Self.loadPersistedQueue()
        bindPeerManager()
    }

    // MARK: - Public

    /// Returns the immediate delivery state. Cloud relay sends complete asynchronously
    /// and report their final state through `onDeliveryStatusChanged`.
    @discardableResult
    public func send(_ message: Message) -> DeliveryStatus {
        if peerManager.isConnected, peerManager.send(message) {
            return .sent
        }

        if let cloudRelay, cloudRelay.isActive {
            Task { @MainActor [weak self, weak cloudRelay] in
                guard let cloudRelay else {
                    let status = self?.queueForRetryIfNeeded(message) == true ? DeliveryStatus.queued : .failed
                    self?.onDeliveryStatusChanged?(message.id, status)
                    return
                }

                let sent = await cloudRelay.send(message)
                if sent {
                    self?.onDeliveryStatusChanged?(message.id, .sent)
                } else {
                    let status = self?.queueForRetryIfNeeded(message) == true ? DeliveryStatus.queued : .failed
                    self?.onDeliveryStatusChanged?(message.id, status)
                }
            }
            return .sending
        }

        if queueForRetryIfNeeded(message) {
            logger.info("Queued message (offline): \(message.id)")
            return .queued
        }

        return .failed
    }

    /// Flush any queued messages — call when connection is restored.
    public func flushPendingQueue() {
        guard !pendingQueue.isEmpty else { return }
        let queued = pendingQueue
        pendingQueue.removeAll()
        persistQueue()
        for message in queued {
            let status = send(message)
            // The cloud-relay path returns `.sending` and reports its own final
            // status asynchronously via `onDeliveryStatusChanged`. Emitting
            // `.sending` here too can race ahead of (and clobber) that async
            // `.sent`, leaving the message stuck on "sending". Only surface the
            // synchronous terminal states; let the async path own `.sending`.
            if status != .sending {
                onDeliveryStatusChanged?(message.id, status)
            }
        }
        logger.info("Flushed \(queued.count) queued messages")
    }

    /// Re-attempt sending a single previously-failed/queued message.
    /// Returns the new delivery status.
    @discardableResult
    public func retry(_ message: Message) -> DeliveryStatus {
        pendingQueue.removeAll { $0.id == message.id }
        persistQueue()
        return send(message)
    }

    // MARK: - Private

    private func bindPeerManager() {
        peerManager.onMessageReceived = { [weak self] message in
            self?.handleIncoming(message)
        }
    }

    private func bindCloudRelay() {
        cloudRelay?.onMessageReceived = { [weak self] message in
            self?.handleIncoming(message)
        }
    }

    private func queue(_ message: Message) {
        guard !pendingQueue.contains(where: { $0.id == message.id }) else { return }
        pendingQueue.append(message)
        persistQueue()
    }

    private func queueForRetryIfNeeded(_ message: Message) -> Bool {
        guard message.type == .text || message.type == .screenshot else { return false }
        queue(message)
        return true
    }

    private func persistQueue() {
        let defaults = UserDefaults.standard
        guard !pendingQueue.isEmpty else {
            defaults.removeObject(forKey: Self.pendingQueueKey)
            return
        }
        let payloads = pendingQueue.compactMap { try? $0.encoded() }
        defaults.set(payloads, forKey: Self.pendingQueueKey)
    }

    private static func loadPersistedQueue() -> [Message] {
        guard let payloads = UserDefaults.standard.array(forKey: pendingQueueKey) as? [Data] else {
            return []
        }
        return payloads.compactMap { try? Message.decoded(from: $0) }
    }

    private func handleIncoming(_ message: Message) {
        evictStaleEntries()

        guard !deliveredIDs.contains(where: { $0.id == message.id }) else { return }
        deliveredIDs.append((id: message.id, time: Date()))

        onMessageReceived?(message)
    }

    private func evictStaleEntries() {
        let cutoff = Date(timeIntervalSinceNow: -Self.dedupWindow)
        deliveredIDs.removeAll { $0.time < cutoff }
    }
}
