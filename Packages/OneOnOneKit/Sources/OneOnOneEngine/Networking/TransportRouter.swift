import Foundation
import os

private let logger = Logger(subsystem: "com.markstudios.OneOnOne", category: "TransportRouter")

/// Routes messages through the best available transport:
/// MultipeerConnectivity (local) preferred, CloudKit relay as fallback.
@Observable
@MainActor
public final class TransportRouter {
    private let peerManager: PeerManager
    private let cloudRelay: CloudRelayManager
    private var deliveredIDs: Set<UUID> = []

    public var onMessageReceived: (@MainActor (Message) -> Void)?

    public init(peerManager: PeerManager, cloudRelay: CloudRelayManager) {
        self.peerManager = peerManager
        self.cloudRelay = cloudRelay
        setupCallbacks()
    }

    // MARK: - Public

    public func send(_ message: Message) {
        if peerManager.isConnected {
            peerManager.send(message)
            logger.info("Sent via MC: \(message.id)")
        } else if cloudRelay.isActive {
            Task {
                await cloudRelay.send(message)
            }
            logger.info("Sent via CloudKit: \(message.id)")
        } else {
            logger.warning("No transport available for message: \(message.id)")
        }
    }

    // MARK: - Private

    private func setupCallbacks() {
        peerManager.onMessageReceived = { [weak self] message in
            self?.handleIncoming(message)
        }

        cloudRelay.onMessageReceived = { [weak self] message in
            self?.handleIncoming(message)
        }
    }

    private func handleIncoming(_ message: Message) {
        // Deduplicate
        guard !deliveredIDs.contains(message.id) else { return }
        deliveredIDs.insert(message.id)

        // Cap dedup set size
        if deliveredIDs.count > 1000 {
            deliveredIDs.removeAll()
        }

        onMessageReceived?(message)
    }
}
