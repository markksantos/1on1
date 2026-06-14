import Foundation
import CloudKit
import CryptoKit
import os

private let logger = Logger(subsystem: "com.markstudios.OneOnOne", category: "CloudRelay")

@Observable
@MainActor
public final class CloudRelayManager {
    private static let clientIDKey = "com.markstudios.1on1.cloudRelayClientID"
    private static let seenIDsKeyPrefix = "com.markstudios.1on1.cloudRelaySeenIDs."
    private static let maxPersistedSeenIDs = 1_000
    private static let queryPageSize = 100
    private static let maxPayloadBytes = 900_000
    private static let activePollInterval: TimeInterval = 2
    private static let idlePollInterval: TimeInterval = 30
    /// Number of consecutive empty polls before we slow down.
    private static let pollsBeforeIdle = 30

    private var container: CKContainer?
    private var database: CKDatabase? { container?.publicCloudDatabase }
    private var roomHash: String?
    private var pollTask: Task<Void, Never>?
    private var seenMessageIDs: Set<String> = []
    private var seenMessageOrder: [String] = []
    private var derivedKey: SymmetricKey?
    private let clientID: String
    private var consecutiveEmptyPolls: Int = 0

    public var onMessageReceived: (@MainActor (Message) -> Void)?
    public private(set) var isActive = false

    public init() {
        clientID = Self.resolveClientID()
    }

    // MARK: - Public API

    public func activate(roomCode: String) async {
        let normalizedRoomCode = roomCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedRoomCode.isEmpty else { return }

        // Lazily initialize CKContainer only when needed.
        let cloudContainer = CKContainer.default()
        container = cloudContainer

        do {
            let accountStatus = try await cloudContainer.accountStatus()
            guard accountStatus == .available else {
                logger.error("CloudKit account unavailable: \(String(describing: accountStatus))")
                return
            }
        } catch {
            logger.error("CloudKit account check failed: \(error.localizedDescription)")
            return
        }

        guard let database else {
            logger.error("CloudKit container not available — is iCloud configured?")
            return
        }
        guard await verifyDatabaseAccess(database) else { return }

        // Derive encryption key from room code via HKDF
        let codeData = Data(normalizedRoomCode.utf8)
        let salt = Data("com.markstudios.1on1.relay".utf8)
        derivedKey = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: codeData),
            salt: salt,
            info: Data("message-encryption".utf8),
            outputByteCount: 32
        )

        let hash = Self.roomHash(for: normalizedRoomCode)
        roomHash = hash
        loadSeenMessageIDs(for: hash)

        isActive = true
        startPolling()
        logger.info("CloudRelay activated")
    }

    public func deactivate() {
        pollTask?.cancel()
        isActive = false
        container = nil
        roomHash = nil
        derivedKey = nil
        seenMessageIDs.removeAll()
        seenMessageOrder.removeAll()
    }

    @discardableResult
    public func send(_ message: Message) async -> Bool {
        guard let database, let roomHash, let derivedKey else { return false }

        do {
            rememberSeenMessageID(message.id.uuidString)

            let data = try message.encoded()
            let sealedBox = try AES.GCM.seal(data, using: derivedKey)
            guard let combined = sealedBox.combined else { return false }
            guard combined.count <= Self.maxPayloadBytes else {
                logger.error("CloudKit payload too large: \(combined.count) bytes")
                return false
            }

            let recordID = CKRecord.ID(recordName: "\(roomHash)-\(message.id.uuidString)")
            let record = CKRecord(recordType: "Message", recordID: recordID)
            record["roomHash"] = roomHash
            record["messageID"] = message.id.uuidString
            record["senderID"] = clientID
            record["payload"] = combined as NSData
            record["timestamp"] = message.timestamp as NSDate

            try await database.save(record)
            logger.info("Sent via CloudKit: \(message.id)")
            return true
        } catch {
            logger.error("CloudKit send failed: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Private

    private static func resolveClientID() -> String {
        if let existing = UserDefaults.standard.string(forKey: clientIDKey) {
            return existing
        }

        let id = UUID().uuidString
        UserDefaults.standard.set(id, forKey: clientIDKey)
        return id
    }

    private static func roomHash(for roomCode: String) -> String {
        let digest = SHA256.hash(data: Data(roomCode.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func seenIDsKey(for roomHash: String) -> String {
        "\(seenIDsKeyPrefix)\(roomHash)"
    }

    private func verifyDatabaseAccess(_ database: CKDatabase) async -> Bool {
        do {
            _ = try await database.record(for: CKRecord.ID(recordName: "__oneonone_capability_probe__"))
            return true
        } catch let error as CKError where error.code == .unknownItem {
            return true
        } catch {
            logger.error("CloudKit relay access failed: \(error.localizedDescription)")
            return false
        }
    }

    private func loadSeenMessageIDs(for roomHash: String) {
        let ids = UserDefaults.standard.stringArray(forKey: Self.seenIDsKey(for: roomHash)) ?? []
        seenMessageOrder = ids
        seenMessageIDs = Set(ids)
    }

    private func rememberSeenMessageID(_ messageID: String) {
        guard seenMessageIDs.insert(messageID).inserted else { return }

        seenMessageOrder.append(messageID)
        if seenMessageOrder.count > Self.maxPersistedSeenIDs {
            seenMessageOrder.removeFirst(seenMessageOrder.count - Self.maxPersistedSeenIDs)
            seenMessageIDs = Set(seenMessageOrder)
        }

        if let roomHash {
            UserDefaults.standard.set(seenMessageOrder, forKey: Self.seenIDsKey(for: roomHash))
        }
    }

    /// Resets polling to the active 2-second cadence. Call when there's
    /// reason to expect new messages soon (user just sent one, popover opened, etc.).
    public func bumpToActivePolling() {
        consecutiveEmptyPolls = 0
    }

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                let interval = self?.currentPollInterval ?? Self.activePollInterval
                try? await Task.sleep(for: .seconds(interval))
                guard !Task.isCancelled else { return }
                await self?.fetchNewMessages()
            }
        }
    }

    private var currentPollInterval: TimeInterval {
        consecutiveEmptyPolls >= Self.pollsBeforeIdle ? Self.idlePollInterval : Self.activePollInterval
    }

    private func fetchNewMessages() async {
        guard let database, let roomHash, let derivedKey else { return }

        let cutoff = Date(timeIntervalSinceNow: -3600)
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "roomHash == %@", roomHash),
            NSPredicate(format: "timestamp > %@", cutoff as NSDate),
        ])
        let query = CKQuery(recordType: "Message", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]

        var deliveredAny = false
        do {
            var page = try await database.records(
                matching: query,
                resultsLimit: Self.queryPageSize
            )
            deliveredAny = processFetchedRecords(page.matchResults, derivedKey: derivedKey) || deliveredAny

            while let cursor = page.queryCursor, !Task.isCancelled {
                page = try await database.records(
                    continuingMatchFrom: cursor,
                    resultsLimit: Self.queryPageSize
                )
                deliveredAny = processFetchedRecords(page.matchResults, derivedKey: derivedKey) || deliveredAny
            }
        } catch {
            logger.error("CloudKit fetch failed: \(error.localizedDescription)")
        }

        if deliveredAny {
            consecutiveEmptyPolls = 0
        } else {
            consecutiveEmptyPolls = min(consecutiveEmptyPolls + 1, Self.pollsBeforeIdle)
        }
    }

    /// Returns `true` if at least one new message was delivered to the listener.
    @discardableResult
    private func processFetchedRecords(
        _ results: [(CKRecord.ID, Result<CKRecord, Error>)],
        derivedKey: SymmetricKey
    ) -> Bool {
        var delivered = false
        for (_, result) in results {
            guard let record = try? result.get(),
                  let messageID = record["messageID"] as? String,
                  !seenMessageIDs.contains(messageID),
                  let payload = record["payload"] as? Data else { continue }

            rememberSeenMessageID(messageID)
            if record["senderID"] as? String == clientID {
                continue
            }

            do {
                let sealedBox = try AES.GCM.SealedBox(combined: payload)
                let decrypted = try AES.GCM.open(sealedBox, using: derivedKey)
                let message = try Message.decoded(from: decrypted).receivedFromRemote()
                onMessageReceived?(message)
                delivered = true
            } catch {
                logger.warning("Failed to decrypt cloud message: \(error.localizedDescription)")
            }
        }
        return delivered
    }
}
