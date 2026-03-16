import AppKit
import SwiftUI
import HotKey
import OneOnOneEngine
import OneOnOneUI

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let peerManager = PeerManager()
    private let overlayManager = OverlayStackManager()
    private let statusBar = StatusBarController()
    private let settingsManager = SettingsManager()
    private let cloudRelay = CloudRelayManager()
    private let screenshotManager = ScreenshotManager()
    private var transportRouter: TransportRouter?
    private var databaseManager: DatabaseManager?
    private var conversationWindowController: ConversationWindowController?
    private var settingsWindowController: SettingsWindowController?
    private var composeHotKey: HotKey?
    private var screenshotHotKey: HotKey?
    private var typingDebounceTask: Task<Void, Never>?
    private var quietHoursQueue: [Message] = []
    private var quietHoursCheckTask: Task<Void, Never>?

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
        peerManager.stop()
        cloudRelay.deactivate()
        quietHoursCheckTask?.cancel()
    }

    // MARK: - Setup

    private func setupDatabase() {
        do {
            databaseManager = try DatabaseManager()
            conversationWindowController = ConversationWindowController(databaseManager: databaseManager!)
        } catch {
            print("Failed to initialize database: \(error)")
        }
    }

    private func setupTransportRouter() {
        let router = TransportRouter(peerManager: peerManager, cloudRelay: cloudRelay)
        router.onMessageReceived = { [weak self] message in
            self?.handleIncomingMessage(message)
        }
        transportRouter = router

        // Typing state still comes directly from PeerManager
        peerManager.onTypingStateChanged = { [weak self] isTyping in
            self?.statusBar.isPartnerTyping = isTyping
        }
    }

    private func setupStatusBar() {
        let composeView = NSHostingView(
            rootView: ComposeView(
                isConnected: peerManager.isConnected,
                partnerName: peerManager.connectedPeer?.displayName ?? settingsManager.partnerName,
                onSend: { [weak self] text in
                    self?.sendTextMessage(text)
                },
                onDismiss: { [weak self] in
                    self?.statusBar.togglePopover()
                },
                onTypingChanged: { [weak self] isTyping in
                    self?.handleTypingChanged(isTyping)
                }
            )
        )
        statusBar.setup(composeView: composeView)
        statusBar.onShowHistory = { [weak self] in
            self?.conversationWindowController?.showWindow()
        }

        settingsWindowController = SettingsWindowController(settings: settingsManager)
        statusBar.onShowSettings = { [weak self] in
            self?.settingsWindowController?.showWindow()
        }

        // Observe connection state
        Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))
                guard let self else { return }
                self.statusBar.isConnected = self.peerManager.isConnected || self.cloudRelay.isActive
            }
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
            guard let self, let data = image.tiffRepresentation else { return }
            let hostName = Host.current().localizedName ?? "Me"
            let message = Message(
                senderName: hostName,
                body: "[Screenshot]",
                type: .text,
                isFromMe: true
            )
            self.transportRouter?.send(message)
            try? self.databaseManager?.save(message)
            // Note: actual image transfer via MC sendResource is Phase 3.2 full implementation
            _ = data
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
        Task {
            await cloudRelay.activate(roomCode: roomCode)
        }
    }

    // MARK: - Messaging

    private func handleIncomingMessage(_ message: Message) {
        try? databaseManager?.save(message)
        statusBar.hasUnread = true

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
        transportRouter?.send(message)
        try? databaseManager?.save(message)
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
