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

    // Keys
    private enum Key {
        static let partnerName = "settings.partnerName"
        static let overlaySize = "settings.overlaySize"
        static let soundEnabled = "settings.soundEnabled"
        static let quietHoursEnabled = "settings.quietHoursEnabled"
        static let quietHoursStart = "settings.quietHoursStart"
        static let quietHoursEnd = "settings.quietHoursEnd"
        static let launchAtLogin = "settings.launchAtLogin"
        static let roomCode = "settings.roomCode"
    }

    public var partnerName: String {
        didSet { Self.defaults.set(partnerName, forKey: Key.partnerName) }
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
        didSet { Self.defaults.set(roomCode, forKey: Key.roomCode) }
    }

    public init() {
        self.partnerName = Self.defaults.string(forKey: Key.partnerName) ?? ""
        self.overlaySize = OverlaySize(rawValue: Self.defaults.string(forKey: Key.overlaySize) ?? "") ?? .medium
        self.soundEnabled = Self.defaults.object(forKey: Key.soundEnabled) as? Bool ?? true
        self.quietHoursEnabled = Self.defaults.bool(forKey: Key.quietHoursEnabled)
        self.launchAtLogin = Self.defaults.bool(forKey: Key.launchAtLogin)
        self.roomCode = Self.defaults.string(forKey: Key.roomCode) ?? ""

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

    // MARK: - Private

    private func updateLoginItem() {
        if launchAtLogin {
            try? SMAppService.mainApp.register()
        } else {
            try? SMAppService.mainApp.unregister()
        }
    }
}
