import AppKit
import SwiftUI
import OneOnOneEngine

public struct ConversationView: View {
    let appState: AppState
    let onClearHistory: () -> Void
    let onOpenSettings: () -> Void
    let onDeleteMessage: ((UUID) -> Void)?
    let onResendMessage: ((UUID) -> Void)?
    let onReconnect: (() -> Void)?
    let onMarkRead: (() -> Void)?

    @State private var searchText = ""

    public init(
        appState: AppState,
        onClearHistory: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void,
        onDeleteMessage: ((UUID) -> Void)? = nil,
        onResendMessage: ((UUID) -> Void)? = nil,
        onReconnect: (() -> Void)? = nil,
        onMarkRead: (() -> Void)? = nil
    ) {
        self.appState = appState
        self.onClearHistory = onClearHistory
        self.onOpenSettings = onOpenSettings
        self.onDeleteMessage = onDeleteMessage
        self.onResendMessage = onResendMessage
        self.onReconnect = onReconnect
        self.onMarkRead = onMarkRead
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            messageList
        }
        .searchable(text: $searchText, prompt: "Search messages")
        .frame(minWidth: 420, minHeight: 520)
        .background(.background)
        .onAppear { onMarkRead?() }
    }

    // MARK: - Subviews

    private var header: some View {
        HStack {
            Button(action: onOpenSettings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(appState.partnerName.isEmpty ? "Conversation" : appState.partnerName)
                    .font(.headline)
                HStack(spacing: 4) {
                    Circle()
                        .fill(statusDotColor)
                        .frame(width: 6, height: 6)
                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()

            if appState.connectionStatus == .offline || appState.connectionStatus == .reconnecting {
                Button("Reconnect") { onReconnect?() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }

            Menu {
                Button("Clear History…", role: .destructive, action: onClearHistory)
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 28)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var statusDotColor: Color {
        switch appState.connectionStatus {
        case .connected: .green
        case .connecting, .reconnecting: appState.isRelayActive ? .blue : .orange
        case .offline: appState.isRelayActive ? .blue : .secondary
        }
    }

    private var statusText: String {
        let count = "\(appState.messages.count) messages"
        switch appState.connectionStatus {
        case .connected: return "Connected · \(count)"
        case .connecting: return "Connecting… · \(count)"
        case .reconnecting: return "\(appState.isRelayActive ? "Relay Ready" : "Reconnecting…") · \(count)"
        case .offline: return "\(appState.isRelayActive ? "Relay Ready" : "Offline") · \(count)"
        }
    }

    // MARK: - Filtered Messages

    private var filteredMessages: [Message] {
        if searchText.isEmpty {
            return appState.messages
        }
        return appState.messages.filter {
            $0.body.localizedCaseInsensitiveContains(searchText)
        }
    }

    @ViewBuilder
    private var messageList: some View {
        if appState.messages.isEmpty {
            ContentUnavailableView(
                "No Messages Yet",
                systemImage: "bubble.left.and.bubble.right",
                description: Text("Messages you send and receive will appear here.")
            )
        } else if filteredMessages.isEmpty && !searchText.isEmpty {
            ContentUnavailableView.search(text: searchText)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(groupedMessages, id: \.date) { group in
                            dateSeparator(group.date)
                            ForEach(group.messages) { message in
                                MessageRow(
                                    message: message,
                                    deliveryStatus: appState.deliveryStatuses[message.id],
                                    lastReadByPartner: appState.lastReadByPartner,
                                    onDelete: onDeleteMessage,
                                    onResend: onResendMessage
                                )
                                .id(message.id)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .onChange(of: appState.messages.count) { _, _ in
                    onMarkRead?()
                    if let last = appState.messages.last {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
                .onAppear {
                    if let last = appState.messages.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private func dateSeparator(_ date: String) -> some View {
        Text(date)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.tertiary)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Grouping

    private var groupedMessages: [MessageGroup] {
        let calendar = Calendar.current
        let formatter = DateFormatter()

        var groups: [String: [Message]] = [:]
        var order: [String] = []

        for message in filteredMessages {
            if calendar.isDateInToday(message.timestamp) {
                formatter.dateFormat = "'Today'"
            } else if calendar.isDateInYesterday(message.timestamp) {
                formatter.dateFormat = "'Yesterday'"
            } else {
                formatter.dateFormat = "EEEE, MMM d"
            }
            let key = formatter.string(from: message.timestamp)
            if groups[key] == nil { order.append(key) }
            groups[key, default: []].append(message)
        }

        return order.map { MessageGroup(date: $0, messages: groups[$0]!) }
    }
}

private struct MessageGroup {
    let date: String
    let messages: [Message]
}

// MARK: - Message Row

private struct MessageRow: View {
    let message: Message
    let deliveryStatus: DeliveryStatus?
    let lastReadByPartner: Date?
    let onDelete: ((UUID) -> Void)?
    let onResend: ((UUID) -> Void)?

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.isFromMe { Spacer(minLength: 80) }

            VStack(alignment: message.isFromMe ? .trailing : .leading, spacing: 2) {
                messageBubble

                HStack(spacing: 4) {
                    Text(message.timestamp, style: .time)
                        .font(.system(size: 10))
                        .foregroundStyle(.quaternary)

                    if message.isFromMe {
                        deliveryIndicator
                    }
                }
            }

            if !message.isFromMe { Spacer(minLength: 80) }
        }
        .padding(.vertical, 1)
    }

    private var canResend: Bool {
        guard message.isFromMe, onResend != nil else { return false }
        switch deliveryStatus {
        case .failed, .queued: return true
        default: return false
        }
    }

    @ViewBuilder
    private var messageBubble: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let image = screenshotImage {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 240, height: 150)
                    .background(.black.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityLabel("Screenshot")
            }

            Text(linkAttributedString(from: message.body, isFromMe: message.isFromMe))
                .font(.system(size: 13))
                .textSelection(.enabled)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(bubbleColor, in: bubbleShape)
        .foregroundStyle(message.isFromMe ? .white : .primary)
        .contextMenu {
            Button("Copy") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(message.body, forType: .string)
            }
            if canResend {
                Button("Resend") {
                    onResend?(message.id)
                }
            }
            if onDelete != nil {
                Divider()
                Button("Delete", role: .destructive) {
                    onDelete?(message.id)
                }
            }
        }
    }

    private var screenshotImage: NSImage? {
        guard message.type == .screenshot,
              let attachmentData = message.attachmentData else { return nil }
        return NSImage(data: attachmentData)
    }

    @ViewBuilder
    private var deliveryIndicator: some View {
        if let lastRead = lastReadByPartner, message.timestamp <= lastRead {
            Text("Read")
                .font(.system(size: 9))
                .foregroundStyle(.blue.opacity(0.7))
        } else if let status = deliveryStatus {
            switch status {
            case .queued:
                resendableLabel("Queued · Retry", color: .orange)
            case .sending:
                Image(systemName: "circle.dotted")
                    .font(.system(size: 9))
                    .foregroundStyle(.quaternary)
            case .sent:
                Image(systemName: "checkmark")
                    .font(.system(size: 9))
                    .foregroundStyle(.quaternary)
            case .failed:
                resendableLabel("Failed · Retry", color: .red)
            }
        }
    }

    @ViewBuilder
    private func resendableLabel(_ text: String, color: Color) -> some View {
        if canResend {
            Button(action: { onResend?(message.id) }) {
                Text(text)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(color)
            }
            .buttonStyle(.plain)
            .help("Click to resend this message")
        } else {
            Text(text.replacingOccurrences(of: " · Retry", with: ""))
                .font(.system(size: 9))
                .foregroundStyle(color)
        }
    }

    private var bubbleColor: Color {
        message.isFromMe ? .blue : Color(.controlBackgroundColor)
    }

    private var bubbleShape: some InsettableShape {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
    }
}
