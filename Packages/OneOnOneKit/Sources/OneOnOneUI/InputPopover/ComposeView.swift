import SwiftUI
import OneOnOneEngine

public struct ComposeView: View {
    let appState: AppState
    let onSend: (String) -> Void
    let onTypingChanged: (Bool) -> Void
    let onReconnect: (() -> Void)?
    let onDraftChanged: ((String) -> Void)?

    @State private var messageText: String
    @FocusState private var isTextFieldFocused: Bool

    public init(
        appState: AppState,
        onSend: @escaping (String) -> Void,
        onTypingChanged: @escaping (Bool) -> Void,
        onReconnect: (() -> Void)? = nil,
        initialDraft: String = "",
        onDraftChanged: ((String) -> Void)? = nil
    ) {
        self.appState = appState
        self.onSend = onSend
        self.onTypingChanged = onTypingChanged
        self.onReconnect = onReconnect
        self.onDraftChanged = onDraftChanged
        self._messageText = State(initialValue: initialDraft)
    }

    public var body: some View {
        VStack(spacing: 12) {
            // Connection header
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
                if appState.connectionStatus == .offline || appState.connectionStatus == .reconnecting {
                    Button("Reconnect") { onReconnect?() }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                }
            }

            // Typing indicator
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

            // Input field
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
        .padding(16)
        .frame(width: 300)
        .onAppear { isTextFieldFocused = true }
        .animation(.easeInOut(duration: 0.2), value: appState.isPartnerTyping)
    }

    // MARK: - Computed

    private var displayName: String {
        let name = appState.partnerName
        return name.isEmpty ? "Waiting for partner…" : name
    }

    private var statusText: String {
        switch appState.connectionStatus {
        case .connected: "Connected"
        case .connecting: "Connecting…"
        case .reconnecting: "Reconnecting…"
        case .offline: "Offline"
        }
    }

    private var canSend: Bool {
        !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && appState.connectionStatus == .connected
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
        case .connecting, .reconnecting: .orange
        case .offline: .secondary
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
