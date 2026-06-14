import SwiftUI
import AppKit
import OneOnOneEngine

public struct SettingsView: View {
    @Bindable var settings: SettingsManager
    @State private var selectedTab: Tab = .profile
    @State private var showingRegenerateConfirm = false

    public init(settings: SettingsManager) {
        self.settings = settings
    }

    enum Tab: String, CaseIterable, Identifiable {
        case profile = "Profile"
        case connection = "Connection"
        case notifications = "Notifications"
        case general = "General"

        var id: String { rawValue }

        var systemImage: String {
            switch self {
            case .profile: "person.crop.circle"
            case .connection: "antenna.radiowaves.left.and.right"
            case .notifications: "bell"
            case .general: "gearshape"
            }
        }
    }

    public var body: some View {
        VStack(spacing: 0) {
            tabBar
            Divider()
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 520, height: 420)
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases) { tab in
                tabButton(tab)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.bar)
    }

    private func tabButton(_ tab: Tab) -> some View {
        Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 3) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: 18, weight: .regular))
                Text(tab.rawValue)
                    .font(.system(size: 11, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(selectedTab == tab ? Color.accentColor.opacity(0.15) : Color.clear)
            }
            .foregroundStyle(selectedTab == tab ? Color.accentColor : Color.secondary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch selectedTab {
        case .profile: profileTab
        case .connection: connectionTab
        case .notifications: notificationsTab
        case .general: generalTab
        }
    }

    // MARK: - Profile

    private var profileTab: some View {
        Form {
            Section {
                TextField("Display Name", text: $settings.myDisplayName)
                    .textFieldStyle(.roundedBorder)
            } header: {
                Text("Your Name")
            } footer: {
                Text("Shared with your partner when you connect.")
            }

            Section {
                HStack(spacing: 8) {
                    Text(settings.myHandle.isEmpty ? "Not generated" : settings.myHandle)
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(settings.myHandle, forType: .string)
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    .buttonStyle(.borderless)
                    .disabled(settings.myHandle.isEmpty)
                    .help("Copy your code")

                    Button {
                        showingRegenerateConfirm = true
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                    .help("Generate a new code")
                    .confirmationDialog(
                        "Generate a new code?",
                        isPresented: $showingRegenerateConfirm
                    ) {
                        Button("Generate New Code", role: .destructive) {
                            settings.regenerateHandle()
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("Your partner has your current code saved. If you change it, you'll need to share the new code with them before they can message you.")
                    }
                }
            } header: {
                Text("Your Code")
            } footer: {
                Text("Share this code with your partner. They'll enter it on the Connection tab to message you.")
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Connection

    private var connectionTab: some View {
        Form {
            Section {
                HStack(spacing: 8) {
                    TextField("Partner's Code", text: $settings.roomCode)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 14, design: .monospaced))

                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(settings.roomCode, forType: .string)
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    .buttonStyle(.borderless)
                    .disabled(settings.roomCode.isEmpty)
                    .help("Copy partner's code")
                }

                if isPartnerCodeSelf {
                    Label("That's your own code. Enter your partner's code instead.", systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.orange)
                }
            } header: {
                Text("Connect to Partner")
            } footer: {
                Text("Enter your partner's code from their Profile tab. You'll be able to message over the internet when you're not on the same network.")
            }
        }
        .formStyle(.grouped)
    }

    private var isPartnerCodeSelf: Bool {
        let normalizedRoom = settings.roomCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let normalizedHandle = settings.myHandle.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return !normalizedRoom.isEmpty && normalizedRoom == normalizedHandle
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
    }

    private var overlayTimeoutBinding: Binding<TimeInterval> {
        Binding(
            get: { settings.overlayTimeout },
            set: { settings.overlayTimeout = $0 }
        )
    }

    // MARK: - General

    private var generalTab: some View {
        Form {
            Picker("Overlay Size", selection: $settings.overlaySize) {
                ForEach(OverlaySize.allCases, id: \.self) { size in
                    Text(size.rawValue).tag(size)
                }
            }
            .pickerStyle(.segmented)

            Toggle("Launch at Login", isOn: $settings.launchAtLogin)
        }
        .formStyle(.grouped)
    }
}
