import SwiftUI
import OneOnOneEngine

public struct ConversationView: View {
    let messages: [Message]
    let onClearHistory: () -> Void

    public init(messages: [Message], onClearHistory: @escaping () -> Void) {
        self.messages = messages
        self.onClearHistory = onClearHistory
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Conversation")
                    .font(.headline)
                Spacer()
                Button("Clear History", role: .destructive, action: onClearHistory)
                    .buttonStyle(.borderless)
                    .foregroundStyle(.red)
            }
            .padding()

            Divider()

            // Messages
            if messages.isEmpty {
                ContentUnavailableView(
                    "No Messages",
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text("Messages will appear here")
                )
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(messages) { message in
                                MessageBubbleView(message: message)
                                    .id(message.id)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: messages.count) { _, _ in
                        if let last = messages.last {
                            withAnimation {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                    .onAppear {
                        if let last = messages.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .frame(minWidth: 400, minHeight: 500)
    }
}

private struct MessageBubbleView: View {
    let message: Message

    var body: some View {
        HStack {
            if message.isFromMe { Spacer(minLength: 60) }

            VStack(alignment: message.isFromMe ? .trailing : .leading, spacing: 4) {
                if !message.isFromMe {
                    Text(message.senderName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(message.body)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        message.isFromMe ? Color.blue : Color.gray.opacity(0.3),
                        in: RoundedRectangle(cornerRadius: 16)
                    )
                    .foregroundStyle(message.isFromMe ? .white : .primary)

                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            if !message.isFromMe { Spacer(minLength: 60) }
        }
    }
}
