import AppKit
import SwiftUI
import OneOnOneEngine

public struct ComposeView: View {
    let appState: AppState
    let settings: SettingsManager
    let onSend: (String) -> Void
    let onTypingChanged: (Bool) -> Void
    let onReconnect: (() -> Void)?
    let onShowSettings: (() -> Void)?
    let onDraftChanged: ((String) -> Void)?

    @State private var messageText: String
    @FocusState private var isTextFieldFocused: Bool

    public init(
        appState: AppState,
        settings: SettingsManager,
        onSend: @escaping (String) -> Void,
        onTypingChanged: @escaping (Bool) -> Void,
        onReconnect: (() -> Void)? = nil,
        onShowSettings: (() -> Void)? = nil,
        initialDraft: String = "",
        onDraftChanged: ((String) -> Void)? = nil
    ) {
        self.appState = appState
        self.settings = settings
        self.onSend = onSend
        self.onTypingChanged = onTypingChanged
        self.onReconnect = onReconnect
        self.onShowSettings = onShowSettings
        self.onDraftChanged = onDraftChanged
        self._messageText = State(initialValue: initialDraft)
    }

    public var body: some View {
        VStack(spacing: 12) {
            header

            if showOnboardingState {
                shareYourCodeCard
            } else {
                if appState.isPartnerTyping {
                    HStack(spacing: 4) {
                        TypingDotsView()
                        Text("\(displayName) is typing")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
                inputField
            }
        }
        .padding(16)
        .frame(width: 320)
        .onAppear {
            if !showOnboardingState { isTextFieldFocused = true }
        }
        .animation(.easeInOut(duration: 0.2), value: appState.isPartnerTyping)
        .animation(.easeInOut(duration: 0.2), value: showOnboardingState)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            connectionDot
            VStack(alignment: .leading, spacing: 1) {
                Text(displayName)
                    .font(.system(size: 13, weight: .semibold))
                Text(statusText)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if needsReconnect {
                Button("Reconnect") { onReconnect?() }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
            }
            if let onShowSettings {
                Button(action: onShowSettings) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Settings")
            }
        }
    }

    // MARK: - Onboarding "share your code" state

    private var showOnboardingState: Bool {
        settings.roomCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var shareYourCodeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Share your code")
                .font(.system(size: 13, weight: .semibold))

            Text("Send this to your partner so they can connect to you.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                Text(settings.myHandle.isEmpty ? "—" : settings.myHandle)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(settings.myHandle, forType: .string)
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                        .labelStyle(.titleAndIcon)
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(settings.myHandle.isEmpty)
            }
            .padding(8)
            .background(.quinary, in: RoundedRectangle(cornerRadius: 8))

            Divider()

            Text("Already have your partner's code?")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Button("Open Connection Settings…") {
                onShowSettings?()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(onShowSettings == nil)
        }
    }

    // MARK: - Input

    private var inputField: some View {
        HStack(spacing: 8) {
            TextField("Message", text: $messageText, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .lineLimit(1...4)
                .focused($isTextFieldFocused)
                .onSubmit(sendMessage)
                .onChange(of: messageText) { _, newValue in
                    onTypingChanged(!newValue.isEmpty)
                    onDraftChanged?(newValue)
                }

            Button(action: sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 24))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(canSend ? Color.blue : Color.secondary)
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
        }
        .padding(10)
        .background(.quinary, in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Computed

    private var displayName: String {
        let name = appState.partnerName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty { return name }
        return showOnboardingState ? "Not connected" : "Waiting for partner…"
    }

    private var statusText: String {
        let partnerName = appState.partnerName.trimmingCharacters(in: .whitespacesAndNewlines)
        let nameSuffix = partnerName.isEmpty ? "" : " to \(partnerName)"

        switch appState.connectionStatus {
        case .connected:
            return partnerName.isEmpty ? "Connected" : "Connected\(nameSuffix)"
        case .connecting:
            return "Connecting\(nameSuffix)…"
        case .reconnecting:
            return appState.isRelayActive ? "Relay Ready" : "Reconnecting\(nameSuffix)…"
        case .offline:
            if appState.isRelayActive {
                return partnerName.isEmpty ? "Relay Ready" : "Relay Ready\(nameSuffix)"
            }
            return showOnboardingState ? "Share your code to connect" : "Waiting for partner…"
        }
    }

    private var needsReconnect: Bool {
        guard !showOnboardingState else { return false }
        return appState.connectionStatus == .offline || appState.connectionStatus == .reconnecting
    }

    private var canSend: Bool {
        !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var connectionDot: some View {
        Circle()
            .fill(dotColor)
            .frame(width: 8, height: 8)
            .overlay {
                if appState.connectionStatus == .reconnecting {
                    Circle()
                        .stroke(dotColor.opacity(0.4), lineWidth: 2)
                        .scaleEffect(1.8)
                        .opacity(0)
                        .animation(
                            .easeOut(duration: 1.2).repeatForever(autoreverses: false),
                            value: appState.connectionStatus
                        )
                }
            }
    }

    private var dotColor: Color {
        switch appState.connectionStatus {
        case .connected: .green
        case .connecting, .reconnecting: appState.isRelayActive ? .blue : .orange
        case .offline: appState.isRelayActive ? .blue : .secondary
        }
    }

    private func sendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        onSend(text)
        messageText = ""
        onTypingChanged(false)
        onDraftChanged?("")
    }
}

// MARK: - Typing Animation

struct TypingDotsView: View {
    @State private var phase = 0

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(.secondary)
                    .frame(width: 4, height: 4)
                    .offset(y: phase == i ? -2 : 0)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.4).repeatForever(autoreverses: true)) {
                phase = 1
            }
            // Stagger the dots
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(150))
                withAnimation(.easeInOut(duration: 0.4).repeatForever(autoreverses: true)) {
                    phase = 2
                }
            }
        }
    }
}
