import AppKit
import SwiftUI
import OneOnOneEngine

public struct MessageOverlayView: View {
    let message: Message
    let panelWidth: CGFloat
    let onReply: ((String) -> Void)?
    let onDismiss: () -> Void

    @State private var replyText = ""
    @State private var isReplying = false
    @State private var appeared = false
    @FocusState private var isReplyFocused: Bool

    public init(
        message: Message,
        panelWidth: CGFloat = 420,
        onReply: ((String) -> Void)?,
        onDismiss: @escaping () -> Void
    ) {
        self.message = message
        self.panelWidth = panelWidth
        self.onReply = onReply
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(spacing: 16) {
            header
            messageBody
            replyArea
        }
        .padding(24)
        .frame(width: panelWidth)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThickMaterial)
                .shadow(color: .black.opacity(0.25), radius: 40, y: 8)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
        }
        .scaleEffect(appeared ? 1.0 : 0.92)
        .opacity(appeared ? 1.0 : 0)
        .onAppear {
            withAnimation(.spring(duration: 0.45, bounce: 0.25)) {
                appeared = true
            }
        }
        .onKeyPress(.escape) {
            if isReplying {
                isReplying = false
                return .handled
            }
            onDismiss()
            return .handled
        }
        .contextMenu {
            Button("Copy Message") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(message.body, forType: .string)
            }
            Divider()
            Button("Dismiss", action: onDismiss)
        }
    }

    // MARK: - Subviews

    private var header: some View {
        HStack(spacing: 12) {
            // Avatar
            ZStack {
                Circle()
                    .fill(.blue.gradient)
                    .frame(width: 40, height: 40)
                Text(String(message.senderName.prefix(1)).uppercased())
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(message.senderName)
                    .font(.system(size: 13, weight: .semibold))
                Text(message.timestamp, style: .relative)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .background(.quaternary, in: Circle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.escape, modifiers: [])
        }
    }

    private var messageBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let image = screenshotImage {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: screenshotThumbnailWidth, height: screenshotThumbnailHeight)
                    .background(.black.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityLabel("Screenshot")
            }

            Text(linkAttributedString(from: message.body))
                .font(.system(size: message.type == .screenshot ? 16 : 22, weight: .medium))
                .multilineTextAlignment(.leading)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var replyArea: some View {
        if isReplying {
            HStack(spacing: 8) {
                TextField("Reply…", text: $replyText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .focused($isReplyFocused)
                    .onSubmit(sendReply)

                Button(action: sendReply) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 22))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(replyText.isEmpty ? Color.secondary : Color.blue)
                }
                .buttonStyle(.plain)
                .disabled(replyText.isEmpty)
            }
            .padding(10)
            .background(.quinary, in: RoundedRectangle(cornerRadius: 8))
            .onAppear { isReplyFocused = true }
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        } else if onReply != nil {
            Button {
                withAnimation(.easeOut(duration: 0.2)) {
                    isReplying = true
                }
            } label: {
                Label("Reply", systemImage: "arrowshape.turn.up.left")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(.quinary, in: Capsule())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)
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

    private var screenshotImage: NSImage? {
        guard message.type == .screenshot,
              let attachmentData = message.attachmentData else { return nil }
        return NSImage(data: attachmentData)
    }

    private var screenshotThumbnailWidth: CGFloat {
        max(240, panelWidth - 48)
    }

    private var screenshotThumbnailHeight: CGFloat {
        min(220, screenshotThumbnailWidth * 9 / 16)
    }
}
