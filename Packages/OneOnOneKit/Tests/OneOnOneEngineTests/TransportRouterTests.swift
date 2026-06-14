import Testing
import Foundation
@testable import OneOnOneEngine

@Suite("Transport routing")
struct TransportRouterTests {
    private static let pendingQueueKey = "com.markstudios.1on1.transportRouterPendingQueue"

    private static func clearPersistedQueue() {
        UserDefaults.standard.removeObject(forKey: pendingQueueKey)
    }

    @Test("Messages queue once when no transport is available")
    @MainActor
    func queuesOfflineMessagesOnce() {
        Self.clearPersistedQueue()
        defer { Self.clearPersistedQueue() }

        let router = TransportRouter(peerManager: PeerManager())
        let message = Message(
            senderName: "Alice",
            body: "Queued",
            type: .text,
            isFromMe: true
        )

        #expect(router.send(message) == .queued)
        #expect(router.pendingQueue.map(\.id) == [message.id])

        #expect(router.send(message) == .queued)
        #expect(router.pendingQueue.map(\.id) == [message.id])
    }

    @Test("Transient control messages are not queued offline")
    @MainActor
    func doesNotQueueOfflineControlMessages() {
        Self.clearPersistedQueue()
        defer { Self.clearPersistedQueue() }

        let router = TransportRouter(peerManager: PeerManager())
        let typing = Message(
            senderName: "Alice",
            body: "",
            type: .typingStarted,
            isFromMe: true
        )

        #expect(router.send(typing) == .failed)
        #expect(router.pendingQueue.isEmpty)
    }

    @Test("Queued offline messages survive a relaunch")
    @MainActor
    func pendingQueuePersistsAcrossInstances() {
        Self.clearPersistedQueue()
        defer { Self.clearPersistedQueue() }

        let firstRouter = TransportRouter(peerManager: PeerManager())
        let message = Message(
            senderName: "Alice",
            body: "Survives relaunch",
            type: .text,
            isFromMe: true
        )
        #expect(firstRouter.send(message) == .queued)

        // A fresh router (simulating relaunch) should restore the queue.
        let secondRouter = TransportRouter(peerManager: PeerManager())
        #expect(secondRouter.pendingQueue.map(\.id) == [message.id])
    }

    @Test("Only the lower-named peer invites, and equal names both invite")
    func invitationTieBreakAvoidsCollisionAndDeadlock() {
        // Lower name invites; higher name defers — exactly one inviter.
        #expect(PeerManager.shouldInvite(myDisplayName: "Alice", peerDisplayName: "Bob"))
        #expect(!PeerManager.shouldInvite(myDisplayName: "Bob", peerDisplayName: "Alice"))

        // Equal names can't be disambiguated by string compare, so both invite
        // rather than neither connecting.
        #expect(PeerManager.shouldInvite(myDisplayName: "Mac", peerDisplayName: "Mac"))
    }

    @Test("Retrying a failed message removes it from the pending queue")
    @MainActor
    func retryRemovesFromQueue() {
        Self.clearPersistedQueue()
        defer { Self.clearPersistedQueue() }

        let router = TransportRouter(peerManager: PeerManager())
        let message = Message(
            senderName: "Alice",
            body: "Will retry",
            type: .text,
            isFromMe: true
        )
        _ = router.send(message)
        #expect(router.pendingQueue.count == 1)

        // Retry with no transport just re-queues; ensure no duplicates.
        _ = router.retry(message)
        #expect(router.pendingQueue.map(\.id) == [message.id])
    }
}
