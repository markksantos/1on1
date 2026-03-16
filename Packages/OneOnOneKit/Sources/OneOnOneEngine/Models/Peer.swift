import Foundation

public enum PeerConnectionState: String, Sendable {
    case disconnected
    case connecting
    case connected
}

public struct Peer: Sendable, Identifiable, Equatable {
    public let id: String
    public let displayName: String
    public var connectionState: PeerConnectionState

    public init(id: String, displayName: String, connectionState: PeerConnectionState = .disconnected) {
        self.id = id
        self.displayName = displayName
        self.connectionState = connectionState
    }
}
