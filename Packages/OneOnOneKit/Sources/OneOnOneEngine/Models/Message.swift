import Foundation

public enum MessageType: String, Codable, Sendable {
    case text
    case screenshot
    case typingStarted
    case typingStopped
    case readReceipt
    /// Sent on connect/relay-activate. The body carries the sender's display name.
    case presence
}

public struct Message: Codable, Sendable, Identifiable, Equatable {
    public let id: UUID
    public let senderName: String
    public let body: String
    public let type: MessageType
    public let timestamp: Date
    public let isFromMe: Bool
    public let attachmentData: Data?
    public let attachmentMimeType: String?

    public init(
        id: UUID = UUID(),
        senderName: String,
        body: String,
        type: MessageType = .text,
        timestamp: Date = Date(),
        isFromMe: Bool,
        attachmentData: Data? = nil,
        attachmentMimeType: String? = nil
    ) {
        self.id = id
        self.senderName = senderName
        self.body = body
        self.type = type
        self.timestamp = timestamp
        self.isFromMe = isFromMe
        self.attachmentData = attachmentData
        self.attachmentMimeType = attachmentMimeType
    }

    public func encoded() throws -> Data {
        try JSONEncoder().encode(self)
    }

    public static func decoded(from data: Data) throws -> Message {
        try JSONDecoder().decode(Message.self, from: data)
    }

    public func receivedFromRemote() -> Message {
        Message(
            id: id,
            senderName: senderName,
            body: body,
            type: type,
            timestamp: timestamp,
            isFromMe: false,
            attachmentData: attachmentData,
            attachmentMimeType: attachmentMimeType
        )
    }
}
