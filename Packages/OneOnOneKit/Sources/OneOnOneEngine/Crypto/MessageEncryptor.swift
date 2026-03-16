import Foundation
import CryptoKit

public enum MessageEncryptor: Sendable {
    private static let keychainKey = "com.markstudios.1on1.encryptionKey"

    /// Returns the symmetric key, creating and persisting one if needed.
    public static func symmetricKey() -> SymmetricKey {
        if let keyData = KeychainManager.load(key: keychainKey) {
            return SymmetricKey(data: keyData)
        }
        let key = SymmetricKey(size: .bits256)
        let keyData = key.withUnsafeBytes { Data($0) }
        _ = KeychainManager.save(key: keychainKey, data: keyData)
        return key
    }

    /// Encrypt data using AES-256-GCM
    public static func encrypt(_ data: Data) throws -> Data {
        let key = symmetricKey()
        let sealedBox = try AES.GCM.seal(data, using: key)
        guard let combined = sealedBox.combined else {
            throw EncryptionError.sealFailed
        }
        return combined
    }

    /// Decrypt data using AES-256-GCM
    public static func decrypt(_ data: Data) throws -> Data {
        let key = symmetricKey()
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        return try AES.GCM.open(sealedBox, using: key)
    }

    public enum EncryptionError: Error {
        case sealFailed
    }
}
