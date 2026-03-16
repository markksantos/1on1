import SwiftUI
import OneOnOneEngine

public struct SettingsView: View {
    @Bindable var settings: SettingsManager

    public init(settings: SettingsManager) {
        self.settings = settings
    }

    public var body: some View {
        Form {
            Section("Partner") {
                TextField("Partner Name", text: $settings.partnerName)
            }

            Section("Overlay") {
                Picker("Size", selection: $settings.overlaySize) {
                    ForEach(OverlaySize.allCases, id: \.self) { size in
                        Text(size.rawValue).tag(size)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Sound") {
                Toggle("Play sound on message", isOn: $settings.soundEnabled)
            }

            Section("Quiet Hours") {
                Toggle("Enable Quiet Hours", isOn: $settings.quietHoursEnabled)
                if settings.quietHoursEnabled {
                    DatePicker("Start", selection: $settings.quietHoursStart, displayedComponents: .hourAndMinute)
                    DatePicker("End", selection: $settings.quietHoursEnd, displayedComponents: .hourAndMinute)
                    Text("Messages during quiet hours are queued and delivered when quiet hours end.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Remote Relay") {
                TextField("Room Code", text: $settings.roomCode)
                    .textFieldStyle(.roundedBorder)
                Text("Share this code with your partner to connect over the internet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("System") {
                Toggle("Launch at Login", isOn: $settings.launchAtLogin)
            }
        }
        .formStyle(.grouped)
        .frame(width: 400)
        .padding()
    }
}
