import Foundation

public enum MessageType: String, Codable, Sendable {
    case text
    case typingStarted
    case typingStopped
    case readReceipt
}

public struct Message: Codable, Sendable, Identifiable, Equatable {
    public let id: UUID
    public let senderName: String
    public let body: String
    public let type: MessageType
    public let timestamp: Date
    public let isFromMe: Bool

    public init(
        id: UUID = UUID(),
        senderName: String,
        body: String,
        type: MessageType = .text,
        timestamp: Date = Date(),
        isFromMe: Bool
    ) {
        self.id = id
        self.senderName = senderName
        self.body = body
        self.type = type
        self.timestamp = timestamp
        self.isFromMe = isFromMe
    }

    public func encoded() throws -> Data {
        try JSONEncoder().encode(self)
    }

    public static func decoded(from data: Data) throws -> Message {
        try JSONDecoder().decode(Message.self, from: data)
    }
}
