import SwiftUI
import OneOnOneEngine

public struct ComposeView: View {
    @State private var messageText = ""
    let isConnected: Bool
    let partnerName: String?
    let onSend: (String) -> Void
    let onDismiss: () -> Void
    let onTypingChanged: (Bool) -> Void

    public init(
        isConnected: Bool,
        partnerName: String?,
        onSend: @escaping (String) -> Void,
        onDismiss: @escaping () -> Void,
        onTypingChanged: @escaping (Bool) -> Void
    ) {
        self.isConnected = isConnected
        self.partnerName = partnerName
        self.onSend = onSend
        self.onDismiss = onDismiss
        self.onTypingChanged = onTypingChanged
    }

    public var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Circle()
                    .fill(isConnected ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)
                Text(partnerName ?? "No partner")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            HStack(spacing: 8) {
                TextField("Message…", text: $messageText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                    .onSubmit(sendMessage)
                    .onChange(of: messageText) { _, newValue in
                        onTypingChanged(!newValue.isEmpty)
                    }

                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(messageText.isEmpty ? .gray : .blue)
                }
                .buttonStyle(.plain)
                .disabled(messageText.isEmpty)
                .keyboardShortcut(.return, modifiers: [])
            }
            .padding(10)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
        }
        .padding(16)
        .frame(width: 320)
    }

    private func sendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        onSend(text)
        messageText = ""
        onTypingChanged(false)
    }
}
