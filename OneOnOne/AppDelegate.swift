import AppKit
import SwiftUI
import HotKey
import OneOnOneEngine
import OneOnOneUI

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }

    // MARK: - Core
    private let appState = AppState()
    private let peerManager = PeerManager()
    private let overlayManager = OverlayStackManager()
    private let settingsManager = SettingsManager()
    private var cloudRelay: CloudRelayManager?
    private let screenshotManager = ScreenshotManager()
    private var transportRouter: TransportRouter?
    private var databaseManager: DatabaseManager?

    // MARK: - Controllers
    private var statusBar: StatusBarController!
    private var conversationWindowController: ConversationWindowController?
    private var settingsWindowController: SettingsWindowController?

    // MARK: - Hotkeys
    private var composeHotKey: HotKey?
    private var screenshotHotKey: HotKey?

    // MARK: - State
    private var typingDebounceTask: Task<Void, Never>?
    private var quietHoursQueue: [Message] = []
    private var quietHoursCheckTask: Task<Void, Never>?

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupDatabase()
        setupTransportRouter()
        setupStatusBar()
        setupOverlayManager()
        setupScreenshot()
        setupHotKeys()
        setupQuietHoursCheck()

        peerManager.start()
        activateCloudRelayIfNeeded()
    }

    func applicationWillTerminate(_ notification: Notification) {
        sendTypingState(false)
        peerManager.stop()
        cloudRelay?.deactivate()
        quietHoursCheckTask?.cancel()
    }

    // MARK: - Setup

    private func setupDatabase() {
        do {
            let db = try DatabaseManager()
            databaseManager = db

            // Reactive sync: push DB changes to AppState
            db.onMessagesChanged = { [weak self] messages in
                self?.appState.messages = messages
            }
            // Initial load
            appState.messages = db.messages

            conversationWindowController = ConversationWindowController(
                appState: appState,
                onClearHistory: { [weak self] in
                    try? self?.databaseManager?.clearHistory()
                }
            )
        } catch {
            print("Failed to initialize database: \(error)")
        }
    }

    private func setupTransportRouter() {
        let router = TransportRouter(peerManager: peerManager)
        router.onMessageReceived = { [weak self] message in
            self?.handleIncomingMessage(message)
        }
        transportRouter = router

        peerManager.onTypingStateChanged = { [weak self] isTyping in
            self?.appState.isPartnerTyping = isTyping
            self?.statusBar.updateIcon()
        }

        peerManager.onConnectionChanged = { [weak self] status in
            guard let self else { return }
            self.appState.connectionStatus = status
            self.appState.isConnected = status == .connected
            self.appState.partnerName = self.peerManager.partnerDisplayName
                ?? self.settingsManager.partnerName
            self.statusBar.updateIcon()

            if status == .connected {
                self.transportRouter?.flushPendingQueue()
            }
        }
    }

    private func setupStatusBar() {
        statusBar = StatusBarController(appState: appState)

        let composeView = NSHostingView(
            rootView: ComposeView(
                appState: appState,
                onSend: { [weak self] text in
                    self?.sendTextMessage(text)
                    self?.statusBar.togglePopover()
                },
                onTypingChanged: { [weak self] isTyping in
                    self?.handleTypingChanged(isTyping)
                },
                onReconnect: { [weak self] in
                    self?.peerManager.reconnectNow()
                },
                initialDraft: settingsManager.composeDraft,
                onDraftChanged: { [weak self] text in
                    self?.settingsManager.composeDraft = text
                }
            )
        )
        statusBar.setup(composeView: composeView)
        statusBar.onShowHistory = { [weak self] in
            self?.conversationWindowController?.showWindow()
        }

        settingsWindowController = SettingsWindowController(settings: settingsManager)
        let openSettings: () -> Void = { [weak self] in
            self?.settingsWindowController?.showWindow()
        }
        statusBar.onShowSettings = openSettings
        conversationWindowController?.onOpenSettings = openSettings
        conversationWindowController?.onDeleteMessage = { [weak self] id in
            try? self?.databaseManager?.deleteMessage(id: id)
        }
        conversationWindowController?.onReconnect = { [weak self] in
            self?.peerManager.reconnectNow()
        }
        conversationWindowController?.onMarkRead = { [weak self] in
            self?.sendReadReceipt()
        }
    }

    private func setupOverlayManager() {
        overlayManager.onReply = { [weak self] text in
            self?.sendTextMessage(text)
        }
        overlayManager.settings = settingsManager
    }

    private func setupScreenshot() {
        screenshotManager.onScreenshotCaptured = { [weak self] image in
            guard let self else { return }
            let hostName = Host.current().localizedName ?? "Me"
            let message = Message(
                senderName: hostName,
                body: "[Screenshot]",
                type: .text,
                isFromMe: true
            )
            self.transportRouter?.send(message)
            try? self.databaseManager?.save(message)
        }
    }

    private func setupHotKeys() {
        composeHotKey = HotKey(key: .one, modifiers: [.command, .shift])
        composeHotKey?.keyDownHandler = { [weak self] in
            self?.statusBar.togglePopover()
        }

        screenshotHotKey = HotKey(key: .two, modifiers: [.command, .shift])
        screenshotHotKey?.keyDownHandler = { [weak self] in
            self?.screenshotManager.captureScreen()
        }
    }

    private func setupQuietHoursCheck() {
        quietHoursCheckTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard !Task.isCancelled, let self else { return }
                if !self.settingsManager.isInQuietHours && !self.quietHoursQueue.isEmpty {
                    let queued = self.quietHoursQueue
                    self.quietHoursQueue.removeAll()
                    for message in queued {
                        self.overlayManager.showMessage(message)
                    }
                }
            }
        }
    }

    private func activateCloudRelayIfNeeded() {
        let roomCode = settingsManager.roomCode
        guard !roomCode.isEmpty else { return }
        let relay = CloudRelayManager()
        cloudRelay = relay
        transportRouter?.cloudRelay = relay
        Task { await relay.activate(roomCode: roomCode) }
    }

    // MARK: - Messaging

    private func handleIncomingMessage(_ message: Message) {
        // Handle read receipts without saving or showing
        if message.type == .readReceipt {
            appState.lastReadByPartner = message.timestamp
            return
        }

        try? databaseManager?.save(message)
        appState.unreadCount += 1
        statusBar.updateIcon()

        if settingsManager.isInQuietHours {
            quietHoursQueue.append(message)
        } else {
            overlayManager.showMessage(message)
        }
    }

    private func sendTextMessage(_ text: String) {
        let hostName = Host.current().localizedName ?? "Me"
        let message = Message(
            senderName: hostName,
            body: text,
            type: .text,
            isFromMe: true
        )

        appState.deliveryStatuses[message.id] = .sending
        let sent = transportRouter?.send(message) ?? false
        appState.deliveryStatuses[message.id] = sent ? .sent : .failed

        try? databaseManager?.save(message)
    }

    private func sendReadReceipt() {
        let hostName = Host.current().localizedName ?? "Me"
        let message = Message(
            senderName: hostName,
            body: "",
            type: .readReceipt,
            isFromMe: true
        )
        transportRouter?.send(message)
    }

    private func handleTypingChanged(_ isTyping: Bool) {
        typingDebounceTask?.cancel()

        if isTyping {
            sendTypingState(true)
            typingDebounceTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled else { return }
                self?.sendTypingState(false)
            }
        } else {
            sendTypingState(false)
        }
    }

    private func sendTypingState(_ isTyping: Bool) {
        guard peerManager.isConnected else { return }
        let hostName = Host.current().localizedName ?? "Me"
        let message = Message(
            senderName: hostName,
            body: "",
            type: isTyping ? .typingStarted : .typingStopped,
            isFromMe: true
        )
        peerManager.send(message)
    }
}
