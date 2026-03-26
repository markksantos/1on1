import SwiftUI
import OneOnOneEngine

public struct SettingsView: View {
    @Bindable var settings: SettingsManager

    public init(settings: SettingsManager) {
        self.settings = settings
    }

    public var body: some View {
        TabView {
            generalTab
                .tabItem { Label("General", systemImage: "gearshape") }
            notificationsTab
                .tabItem { Label("Notifications", systemImage: "bell") }
            connectionTab
                .tabItem { Label("Connection", systemImage: "antenna.radiowaves.left.and.right") }
        }
        .frame(width: 420, height: 320)
    }

    // MARK: - General

    private var generalTab: some View {
        Form {
            TextField("Partner Name", text: $settings.partnerName)
                .textFieldStyle(.roundedBorder)

            Picker("Overlay Size", selection: $settings.overlaySize) {
                ForEach(OverlaySize.allCases, id: \.self) { size in
                    Text(size.rawValue).tag(size)
                }
            }
            .pickerStyle(.segmented)

            Toggle("Launch at Login", isOn: $settings.launchAtLogin)
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
    }

    // MARK: - Notifications

    private var notificationsTab: some View {
        Form {
            Toggle("Message Sound", isOn: $settings.soundEnabled)

            Section("Overlay") {
                Picker("Auto-Dismiss After", selection: overlayTimeoutBinding) {
                    Text("1 minute").tag(60.0 as TimeInterval)
                    Text("5 minutes").tag(300.0 as TimeInterval)
                    Text("10 minutes").tag(600.0 as TimeInterval)
                    Text("30 minutes").tag(1800.0 as TimeInterval)
                    Text("Never").tag(0.0 as TimeInterval)
                }
            }

            Section("Quiet Hours") {
                Toggle("Enable Quiet Hours", isOn: $settings.quietHoursEnabled)

                if settings.quietHoursEnabled {
                    DatePicker("From", selection: $settings.quietHoursStart, displayedComponents: .hourAndMinute)
                    DatePicker("Until", selection: $settings.quietHoursEnd, displayedComponents: .hourAndMinute)
                }
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
    }

    private var overlayTimeoutBinding: Binding<TimeInterval> {
        Binding(
            get: { settings.overlayTimeout },
            set: { settings.overlayTimeout = $0 }
        )
    }

    // MARK: - Connection

    private var connectionTab: some View {
        Form {
            Section {
                TextField("Room Code", text: $settings.roomCode)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 14, design: .monospaced))
            } header: {
                Text("CloudKit Relay")
            } footer: {
                Text("Enter the same code on both devices to message over the internet when not on the same network.")
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
    }
}
