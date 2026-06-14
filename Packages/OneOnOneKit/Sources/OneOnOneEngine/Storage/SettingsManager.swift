import Foundation
import ServiceManagement

public enum OverlaySize: String, CaseIterable, Sendable {
    case small = "Small"
    case medium = "Medium"
    case large = "Large"

    public var textSize: CGFloat {
        switch self {
        case .small: 20
        case .medium: 28
        case .large: 36
        }
    }

    public var panelWidth: CGFloat {
        switch self {
        case .small: 360
        case .medium: 440
        case .large: 540
        }
    }
}

@Observable
public final class SettingsManager: @unchecked Sendable {
    nonisolated(unsafe) private static let defaults = UserDefaults.standard

    public var onRoomCodeChanged: ((String) -> Void)?
    public var onMyDisplayNameChanged: ((String) -> Void)?

    // Keys
    private enum Key {
        static let myDisplayName = "settings.myDisplayName"
        static let myHandle = "settings.myHandle"
        static let lastPartnerName = "settings.lastPartnerName"
        static let overlaySize = "settings.overlaySize"
        static let soundEnabled = "settings.soundEnabled"
        static let quietHoursEnabled = "settings.quietHoursEnabled"
        static let quietHoursStart = "settings.quietHoursStart"
        static let quietHoursEnd = "settings.quietHoursEnd"
        static let launchAtLogin = "settings.launchAtLogin"
        static let roomCode = "settings.roomCode"
        static let overlayTimeout = "settings.overlayTimeout"
        static let composeDraft = "settings.composeDraft"
        static let hasCompletedOnboarding = "settings.hasCompletedOnboarding"
    }

    /// My own display name. Defaults to the system computer name; user-editable.
    /// Broadcast to my partner via presence messages.
    public var myDisplayName: String {
        didSet {
            Self.defaults.set(myDisplayName, forKey: Key.myDisplayName)
            if myDisplayName != oldValue {
                onMyDisplayNameChanged?(myDisplayName)
            }
        }
    }

    /// My own unique handle/code. Auto-generated on first launch; persistent.
    /// Shareable with a partner so they can connect to me.
    public var myHandle: String {
        didSet { Self.defaults.set(myHandle, forKey: Key.myHandle) }
    }

    /// Last known partner display name, sourced from presence messages.
    /// Persisted so the UI shows their name immediately after relaunch.
    public var lastPartnerName: String {
        didSet { Self.defaults.set(lastPartnerName, forKey: Key.lastPartnerName) }
    }

    public var overlaySize: OverlaySize {
        didSet { Self.defaults.set(overlaySize.rawValue, forKey: Key.overlaySize) }
    }

    public var soundEnabled: Bool {
        didSet { Self.defaults.set(soundEnabled, forKey: Key.soundEnabled) }
    }

    public var quietHoursEnabled: Bool {
        didSet { Self.defaults.set(quietHoursEnabled, forKey: Key.quietHoursEnabled) }
    }

    public var quietHoursStart: Date {
        didSet { Self.defaults.set(quietHoursStart.timeIntervalSinceReferenceDate, forKey: Key.quietHoursStart) }
    }

    public var quietHoursEnd: Date {
        didSet { Self.defaults.set(quietHoursEnd.timeIntervalSinceReferenceDate, forKey: Key.quietHoursEnd) }
    }

    public var launchAtLogin: Bool {
        didSet {
            Self.defaults.set(launchAtLogin, forKey: Key.launchAtLogin)
            updateLoginItem()
        }
    }

    public var roomCode: String {
        didSet {
            Self.defaults.set(roomCode, forKey: Key.roomCode)
            if roomCode != oldValue {
                onRoomCodeChanged?(roomCode)
            }
        }
    }

    /// Overlay auto-dismiss timeout in seconds. 0 means never auto-dismiss.
    public var overlayTimeout: TimeInterval {
        didSet { Self.defaults.set(overlayTimeout, forKey: Key.overlayTimeout) }
    }

    public var composeDraft: String {
        didSet { Self.defaults.set(composeDraft, forKey: Key.composeDraft) }
    }

    /// `true` after the user dismisses the welcome screen. False on first launch.
    public var hasCompletedOnboarding: Bool {
        didSet { Self.defaults.set(hasCompletedOnboarding, forKey: Key.hasCompletedOnboarding) }
    }

    public init() {
        let defaultName = Host.current().localizedName ?? "Me"
        let storedName = Self.defaults.string(forKey: Key.myDisplayName) ?? ""
        self.myDisplayName = storedName.isEmpty ? defaultName : storedName

        if let existing = Self.defaults.string(forKey: Key.myHandle), !existing.isEmpty {
            self.myHandle = existing
        } else {
            let generated = Self.generateHandle()
            self.myHandle = generated
            Self.defaults.set(generated, forKey: Key.myHandle)
        }

        self.lastPartnerName = Self.defaults.string(forKey: Key.lastPartnerName) ?? ""
        self.overlaySize = OverlaySize(rawValue: Self.defaults.string(forKey: Key.overlaySize) ?? "") ?? .medium
        self.soundEnabled = Self.defaults.object(forKey: Key.soundEnabled) as? Bool ?? false
        self.quietHoursEnabled = Self.defaults.bool(forKey: Key.quietHoursEnabled)
        self.launchAtLogin = Self.defaults.bool(forKey: Key.launchAtLogin)
        self.roomCode = Self.defaults.string(forKey: Key.roomCode) ?? ""
        self.overlayTimeout = Self.defaults.object(forKey: Key.overlayTimeout) as? TimeInterval ?? 300
        self.composeDraft = Self.defaults.string(forKey: Key.composeDraft) ?? ""
        self.hasCompletedOnboarding = Self.defaults.bool(forKey: Key.hasCompletedOnboarding)

        // Quiet hours default: 10 PM to 8 AM
        let calendar = Calendar.current
        if let startTime = Self.defaults.object(forKey: Key.quietHoursStart) as? TimeInterval {
            self.quietHoursStart = Date(timeIntervalSinceReferenceDate: startTime)
        } else {
            self.quietHoursStart = calendar.date(from: DateComponents(hour: 22)) ?? Date()
        }
        if let endTime = Self.defaults.object(forKey: Key.quietHoursEnd) as? TimeInterval {
            self.quietHoursEnd = Date(timeIntervalSinceReferenceDate: endTime)
        } else {
            self.quietHoursEnd = calendar.date(from: DateComponents(hour: 8)) ?? Date()
        }
    }

    // MARK: - Quiet Hours

    public var isInQuietHours: Bool {
        guard quietHoursEnabled else { return false }
        let calendar = Calendar.current
        let now = Date()
        let currentMinutes = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)
        let startMinutes = calendar.component(.hour, from: quietHoursStart) * 60 + calendar.component(.minute, from: quietHoursStart)
        let endMinutes = calendar.component(.hour, from: quietHoursEnd) * 60 + calendar.component(.minute, from: quietHoursEnd)

        if startMinutes <= endMinutes {
            return currentMinutes >= startMinutes && currentMinutes < endMinutes
        } else {
            // Overnight: e.g., 10 PM to 8 AM
            return currentMinutes >= startMinutes || currentMinutes < endMinutes
        }
    }

    // MARK: - Handle generation

    /// Generates a fresh handle and returns it without persisting.
    /// Caller assigns it to `myHandle` to persist + notify observers.
    public static func generateHandle() -> String {
        // Unambiguous alphabet: no 0/O, 1/I/L
        let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        var rng = SystemRandomNumberGenerator()
        var code = ""
        for i in 0..<12 {
            if i > 0 && i % 4 == 0 { code.append("-") }
            code.append(alphabet[Int(rng.next() % UInt64(alphabet.count))])
        }
        return code
    }

    public func regenerateHandle() {
        myHandle = Self.generateHandle()
    }

    // MARK: - Private

    private func updateLoginItem() {
        if launchAtLogin {
            try? SMAppService.mainApp.register()
        } else {
            try? SMAppService.mainApp.unregister()
        }
    }
}
