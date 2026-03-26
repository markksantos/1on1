import Foundation
import MultipeerConnectivity
import os

private let logger = Logger(subsystem: "com.markstudios.OneOnOne", category: "PeerManager")

@Observable
@MainActor
public final class PeerManager: NSObject, @unchecked Sendable {
    // MARK: - Constants
    private static let serviceType = "1on1"
    private static let peerIDKey = "com.markstudios.1on1.peerID"
    private static let partnerNameKey = "com.markstudios.1on1.partnerName"
    private static let maxBackoff: TimeInterval = 30
    private static let typingTimeout: TimeInterval = 8

    // MARK: - Published State
    public private(set) var connectedPeer: Peer?
    public private(set) var isConnected = false
    public private(set) var connectionStatus: ConnectionStatus = .offline

    // MARK: - Callbacks
    public var onMessageReceived: (@MainActor (Message) -> Void)?
    public var onTypingStateChanged: (@MainActor (Bool) -> Void)?
    public var onConnectionChanged: (@MainActor (ConnectionStatus) -> Void)?

    // MARK: - Private
    private let myPeerID: MCPeerID
    nonisolated(unsafe) private let _session: MCSession
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private var reconnectBackoff: TimeInterval = 2
    private var reconnectTask: Task<Void, Never>?
    private var typingTimeoutTask: Task<Void, Never>?
    private var storedPartnerName: String? {
        get { UserDefaults.standard.string(forKey: Self.partnerNameKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.partnerNameKey) }
    }

    public var partnerDisplayName: String? {
        connectedPeer?.displayName ?? storedPartnerName
    }

    // MARK: - Init
    public override init() {
        if let data = UserDefaults.standard.data(forKey: Self.peerIDKey),
           let archived = try? NSKeyedUnarchiver.unarchivedObject(ofClass: MCPeerID.self, from: data) {
            myPeerID = archived
        } else {
            let hostName = Host.current().localizedName ?? "Mac"
            myPeerID = MCPeerID(displayName: hostName)
            if let data = try? NSKeyedArchiver.archivedData(withRootObject: myPeerID, requiringSecureCoding: true) {
                UserDefaults.standard.set(data, forKey: Self.peerIDKey)
            }
        }

        _session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
        super.init()
        _session.delegate = self
    }

    // MARK: - Public API

    public func start() {
        startAdvertising()
        startBrowsing()
        logger.info("PeerManager started as \(self.myPeerID.displayName)")
    }

    public func stop() {
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        _session.disconnect()
        reconnectTask?.cancel()
        typingTimeoutTask?.cancel()
        isConnected = false
        connectionStatus = .offline
        connectedPeer = nil
    }

    public func reconnectNow() {
        reconnectTask?.cancel()
        resetBackoff()
        stop()
        start()
    }

    public func send(_ message: Message) {
        guard let data = try? message.encoded(),
              !_session.connectedPeers.isEmpty else {
            logger.warning("Cannot send — no connected peers")
            return
        }
        do {
            try _session.send(data, toPeers: _session.connectedPeers, with: .reliable)
        } catch {
            logger.error("Send failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Private Networking

    private func startAdvertising() {
        let adv = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: nil, serviceType: Self.serviceType)
        adv.delegate = self
        adv.startAdvertisingPeer()
        advertiser = adv
    }

    private func startBrowsing() {
        let brw = MCNearbyServiceBrowser(peer: myPeerID, serviceType: Self.serviceType)
        brw.delegate = self
        brw.startBrowsingForPeers()
        browser = brw
    }

    private func scheduleReconnect() {
        reconnectTask?.cancel()
        connectionStatus = .reconnecting
        onConnectionChanged?(.reconnecting)
        let delay = reconnectBackoff
        reconnectBackoff = min(reconnectBackoff * 2, Self.maxBackoff)

        reconnectTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            self?.start()
        }
        logger.info("Reconnect scheduled in \(delay)s")
    }

    private func resetBackoff() {
        reconnectBackoff = 2
    }

    private func startTypingTimeout() {
        typingTimeoutTask?.cancel()
        typingTimeoutTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(Self.typingTimeout))
            guard !Task.isCancelled else { return }
            self?.onTypingStateChanged?(false)
        }
    }
}

// MARK: - MCSessionDelegate
extension PeerManager: MCSessionDelegate {
    nonisolated public func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        let name = peerID.displayName
        Task { @MainActor [weak self] in
            guard let self else { return }
            switch state {
            case .connected:
                logger.info("Connected to \(name)")
                self.isConnected = true
                self.connectionStatus = .connected
                self.connectedPeer = Peer(id: name, displayName: name, connectionState: .connected)
                self.storedPartnerName = name
                self.resetBackoff()
                self.onConnectionChanged?(.connected)

            case .connecting:
                logger.info("Connecting to \(name)")
                self.connectionStatus = .connecting
                self.connectedPeer = Peer(id: name, displayName: name, connectionState: .connecting)
                self.onConnectionChanged?(.connecting)

            case .notConnected:
                logger.info("Disconnected from \(name)")
                self.isConnected = false
                self.connectedPeer = Peer(id: name, displayName: name, connectionState: .disconnected)
                self.scheduleReconnect()

            @unknown default:
                break
            }
        }
    }

    nonisolated public func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let message = try? Message.decoded(from: data) else {
            logger.warning("Failed to decode message from \(peerID.displayName)")
            return
        }
        Task { @MainActor [weak self] in
            guard let self else { return }
            switch message.type {
            case .typingStarted:
                self.onTypingStateChanged?(true)
                self.startTypingTimeout()
            case .typingStopped:
                self.typingTimeoutTask?.cancel()
                self.onTypingStateChanged?(false)
            case .text, .readReceipt:
                self.typingTimeoutTask?.cancel()
                self.onTypingStateChanged?(false)
                self.onMessageReceived?(message)
            }
        }
    }

    nonisolated public func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    nonisolated public func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    nonisolated public func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - MCNearbyServiceAdvertiserDelegate
extension PeerManager: MCNearbyServiceAdvertiserDelegate {
    nonisolated public func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        logger.info("Received invitation from \(peerID.displayName)")
        invitationHandler(true, _session)
    }

    nonisolated public func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        logger.error("Failed to advertise: \(error.localizedDescription)")
    }
}

// MARK: - MCNearbyServiceBrowserDelegate
extension PeerManager: MCNearbyServiceBrowserDelegate {
    nonisolated public func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        logger.info("Found peer: \(peerID.displayName)")
        browser.invitePeer(peerID, to: _session, withContext: nil, timeout: 10)
    }

    nonisolated public func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        logger.info("Lost peer: \(peerID.displayName)")
    }

    nonisolated public func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        logger.error("Failed to browse: \(error.localizedDescription)")
    }
}
