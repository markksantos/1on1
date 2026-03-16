import Foundation
import CloudKit
import CryptoKit
import os

private let logger = Logger(subsystem: "com.markstudios.OneOnOne", category: "CloudRelay")

@Observable
@MainActor
public final class CloudRelayManager {
    private let container = CKContainer.default()
    private var database: CKDatabase { container.privateCloudDatabase }
    private var zoneID: CKRecordZone.ID?
    private var pollTask: Task<Void, Never>?
    private var seenMessageIDs: Set<String> = []
    private var derivedKey: SymmetricKey?

    public var onMessageReceived: (@MainActor (Message) -> Void)?
    public private(set) var isActive = false

    public init() {}

    // MARK: - Public API

    public func activate(roomCode: String) async {
        guard !roomCode.isEmpty else { return }

        // Derive encryption key from room code via HKDF
        let codeData = Data(roomCode.utf8)
        let salt = Data("com.markstudios.1on1.relay".utf8)
        derivedKey = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: codeData),
            salt: salt,
            info: Data("message-encryption".utf8),
            outputByteCount: 32
        )

        let zoneName = "Room-\(roomCode)"
        zoneID = CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)

        // Create zone if needed
        let zone = CKRecordZone(zoneID: zoneID!)
        do {
            try await database.save(zone)
        } catch {
            logger.warning("Zone may already exist: \(error.localizedDescription)")
        }

        isActive = true
        startPolling()
        logger.info("CloudRelay activated for room: \(roomCode)")
    }

    public func deactivate() {
        pollTask?.cancel()
        isActive = false
        zoneID = nil
        derivedKey = nil
        seenMessageIDs.removeAll()
    }

    public func send(_ message: Message) async {
        guard let zoneID, let derivedKey else { return }

        do {
            let data = try message.encoded()
            let sealedBox = try AES.GCM.seal(data, using: derivedKey)
            guard let combined = sealedBox.combined else { return }

            let record = CKRecord(recordType: "Message", recordID: CKRecord.ID(zoneID: zoneID))
            record["messageID"] = message.id.uuidString
            record["payload"] = combined as NSData
            record["timestamp"] = message.timestamp as NSDate

            try await database.save(record)
            logger.info("Sent via CloudKit: \(message.id)")
        } catch {
            logger.error("CloudKit send failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Private

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { return }
                await self?.fetchNewMessages()
            }
        }
    }

    private func fetchNewMessages() async {
        guard let zoneID, let derivedKey else { return }

        let cutoff = Date(timeIntervalSinceNow: -3600) // last hour
        let predicate = NSPredicate(format: "timestamp > %@", cutoff as NSDate)
        let query = CKQuery(recordType: "Message", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]

        do {
            let (results, _) = try await database.records(matching: query, inZoneWith: zoneID)

            for (_, result) in results {
                guard let record = try? result.get(),
                      let messageID = record["messageID"] as? String,
                      !seenMessageIDs.contains(messageID),
                      let payload = record["payload"] as? Data else { continue }

                seenMessageIDs.insert(messageID)

                do {
                    let sealedBox = try AES.GCM.SealedBox(combined: payload)
                    let decrypted = try AES.GCM.open(sealedBox, using: derivedKey)
                    let message = try Message.decoded(from: decrypted)
                    if !message.isFromMe {
                        onMessageReceived?(message)
                    }
                } catch {
                    logger.warning("Failed to decrypt cloud message: \(error.localizedDescription)")
                }
            }
        } catch {
            logger.error("CloudKit fetch failed: \(error.localizedDescription)")
        }
    }
}
