import Foundation
import os

private let logger = Logger(subsystem: "com.markstudios.OneOnOne", category: "TransportRouter")

/// Routes messages through the best available transport:
/// MultipeerConnectivity (local) preferred, CloudKit relay as fallback.
/// Queues messages when no transport is available for retry on reconnect.
@Observable
@MainActor
public final class TransportRouter {
    private let peerManager: PeerManager
    public var cloudRelay: CloudRelayManager? {
        didSet { bindCloudRelay() }
    }

    /// Time-ordered dedup buffer — evicts entries older than 5 minutes
    private var deliveredIDs: [(id: UUID, time: Date)] = []
    private static let dedupWindow: TimeInterval = 300

    /// Messages queued while offline, delivered on reconnect
    public private(set) var pendingQueue: [Message] = []

    public var onMessageReceived: (@MainActor (Message) -> Void)?

    public init(peerManager: PeerManager) {
        self.peerManager = peerManager
        bindPeerManager()
    }

    // MARK: - Public

    /// Returns `true` if the message was sent via a transport, `false` if queued.
    @discardableResult
    public func send(_ message: Message) -> Bool {
        if peerManager.isConnected {
            peerManager.send(message)
            return true
        } else if let cloudRelay, cloudRelay.isActive {
            Task { await cloudRelay.send(message) }
            return true
        } else {
            pendingQueue.append(message)
            logger.info("Queued message (offline): \(message.id)")
            return false
        }
    }

    /// Flush any queued messages — call when connection is restored.
    public func flushPendingQueue() {
        guard !pendingQueue.isEmpty else { return }
        let queued = pendingQueue
        pendingQueue.removeAll()
        for message in queued {
            send(message)
        }
        logger.info("Flushed \(queued.count) queued messages")
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
