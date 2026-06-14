import Foundation

public enum DeliveryStatus: String, Sendable {
    case queued
    case sending
    case sent
    case failed
}

/// Central observable state container for all SwiftUI views.
/// Updated by AppDelegate from the various managers. Views observe this
/// to get live, reactive updates without coupling to networking/storage layers.
@Observable
@MainActor
public final class AppState {
    public var isConnected = false
    public var partnerName: String = ""
    public var isPartnerTyping = false
    public var isRelayActive = false
    public var messages: [Message] = []
    public var connectionStatus: ConnectionStatus = .offline
    public var unreadCount: Int = 0
    public var lastReadByPartner: Date?
    public var deliveryStatuses: [UUID: DeliveryStatus] = [:]

    public init() {}
}

public enum ConnectionStatus: String, Sendable {
    case offline
    case connecting
    case connected
    case reconnecting
}
