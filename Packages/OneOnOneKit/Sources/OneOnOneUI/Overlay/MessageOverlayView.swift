import SwiftUI
import OneOnOneEngine

public struct MessageOverlayView: View {
    let message: Message
    let onReply: ((String) -> Void)?
    let onDismiss: () -> Void

    @State private var replyText = ""
    @State private var isReplying = false
    @State private var appeared = false

    public init(
        message: Message,
        onReply: ((String) -> Void)?,
        onDismiss: @escaping () -> Void
    ) {
        self.message = message
        self.onReply = onReply
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                // Sender avatar
                Circle()
                    .fill(Color.blue.gradient)
                    .frame(width: 44, height: 44)
                    .overlay {
                        Text(String(message.senderName.prefix(1)).uppercased())
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(message.senderName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                    Text(message.timestamp, style: .relative)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.5))
                }

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
            }

            // Message body
            Text(message.body)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)

            // Reply area
            if isReplying {
                HStack(spacing: 8) {
                    TextField("Reply…", text: $replyText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 15))
                        .foregroundStyle(.white)
                        .onSubmit(sendReply)

                    Button("Send", action: sendReply)
                        .buttonStyle(.plain)
                        .foregroundStyle(.blue)
                        .disabled(replyText.isEmpty)
                }
                .padding(10)
                .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
            } else if onReply != nil {
                Button {
                    isReplying = true
                } label: {
                    Label("Reply", systemImage: "arrowshape.turn.up.left.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.white.opacity(0.15), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(24)
        .frame(width: 440)
        .background(.ultraThinMaterial.opacity(0.9), in: RoundedRectangle(cornerRadius: 20))
        .background(Color.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.4), radius: 30, y: 10)
        .scaleEffect(appeared ? 1.0 : 0.9)
        .opacity(appeared ? 1.0 : 0)
        .onAppear {
            withAnimation(.spring(duration: 0.4, bounce: 0.3)) {
                appeared = true
            }
        }
    }

    private func sendReply() {
        let text = replyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        onReply?(text)
        replyText = ""
        isReplying = false
        onDismiss()
    }
}
