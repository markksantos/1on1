import Foundation
import GRDB
import os

private let logger = Logger(subsystem: "com.markstudios.OneOnOne", category: "DatabaseManager")

/// Persistent record type for GRDB storage
public struct MessageRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    public static let databaseTableName = "messages"

    public let id: String
    public let senderName: String
    public let body: String
    public let type: String
    public let timestamp: Date
    public let isFromMe: Bool

    public init(from message: Message) {
        self.id = message.id.uuidString
        self.senderName = message.senderName
        self.body = message.body
        self.type = message.type.rawValue
        self.timestamp = message.timestamp
        self.isFromMe = message.isFromMe
    }

    public func toMessage() -> Message? {
        guard let uuid = UUID(uuidString: id),
              let messageType = MessageType(rawValue: type) else { return nil }
        return Message(
            id: uuid,
            senderName: senderName,
            body: body,
            type: messageType,
            timestamp: timestamp,
            isFromMe: isFromMe
        )
    }
}

@Observable
@MainActor
public final class DatabaseManager {
    private let dbQueue: DatabaseQueue
    private var observationCancellable: AnyDatabaseCancellable?

    public private(set) var messages: [Message] = []
    public var onMessagesChanged: (([Message]) -> Void)?

    public init() throws {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dbDir = appSupport.appendingPathComponent("OneOnOne", isDirectory: true)
        try FileManager.default.createDirectory(at: dbDir, withIntermediateDirectories: true)

        let dbPath = dbDir.appendingPathComponent("messages.sqlite").path
        dbQueue = try DatabaseQueue(path: dbPath)
        try migrate()
        try loadMessages()
        startObservation()
    }

    nonisolated deinit {
        // observationCancellable is automatically cleaned up when the DatabaseQueue is released
    }

    // MARK: - Public API

    public func save(_ message: Message) throws {
        guard message.type == .text else { return }
        let record = MessageRecord(from: message)
        try dbQueue.write { db in
            try record.insert(db)
        }
    }

    public func allMessages() throws -> [Message] {
        try dbQueue.read { db in
            try MessageRecord
                .order(Column("timestamp").asc)
                .fetchAll(db)
                .compactMap { $0.toMessage() }
        }
    }

    public func deleteMessage(id: UUID) throws {
        try dbQueue.write { db in
            try db.execute(sql: "DELETE FROM messages WHERE id = ?", arguments: [id.uuidString])
        }
    }

    public func clearHistory() throws {
        try dbQueue.write { db in
            try MessageRecord.deleteAll(db)
        }
        messages = []
    }

    // MARK: - Private

    private func migrate() throws {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1") { db in
            try db.create(table: "messages") { t in
                t.column("id", .text).primaryKey()
                t.column("senderName", .text).notNull()
                t.column("body", .text).notNull()
                t.column("type", .text).notNull()
                t.column("timestamp", .datetime).notNull()
                t.column("isFromMe", .boolean).notNull()
            }
        }
        try migrator.migrate(dbQueue)
    }

    private func loadMessages() throws {
        messages = try allMessages()
    }

    private func startObservation() {
        let observation = ValueObservation.tracking { db in
            try MessageRecord
                .order(Column("timestamp").asc)
                .fetchAll(db)
        }

        observationCancellable = observation.start(in: dbQueue, onError: { error in
            logger.error("DB observation error: \(error.localizedDescription)")
        }, onChange: { [weak self] records in
            Task { @MainActor [weak self] in
                let messages = records.compactMap { $0.toMessage() }
                self?.messages = messages
                self?.onMessagesChanged?(messages)
            }
        })
    }
}
