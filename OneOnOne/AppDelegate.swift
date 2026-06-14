import AppKit
import SwiftUI
import HotKey
import OneOnOneEngine
import OneOnOneUI
import os

private let logger = Logger(subsystem: "com.markstudios.OneOnOne", category: "AppDelegate")

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let quietHoursPendingIDsKey = "com.markstudios.1on1.quietHoursPendingMessageIDs"

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
    private var welcomeWindowController: WelcomeWindowController?
    private var aboutWindowController: AboutWindowController?

    // MARK: - Hotkeys
    private var composeHotKey: HotKey?
    private var screenshotHotKey: HotKey?

    // MARK: - State
    private var typingDebounceTask: Task<Void, Never>?
    private var quietHoursQueue: [Message] = []
    private var quietHoursCheckTask: Task<Void, Never>?
    private var cloudRelayActivationTask: Task<Void, Never>?
    private var activeRoomCode = ""

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMainMenu()
        setupDatabase()
        setupTransportRouter()
        setupStatusBar()
        setupOverlayManager()
        setupScreenshot()
        setupHotKeys()
        setupQuietHoursCheck()
        setupSettingsObservation()

        // Seed partner name from the last known presence so the UI shows their
        // name immediately on launch, before they re-broadcast.
        appState.partnerName = settingsManager.lastPartnerName

        peerManager.start()
        activateCloudRelayIfNeeded()

        welcomeWindowController = WelcomeWindowController(settings: settingsManager)
        welcomeWindowController?.showIfNeeded()
    }

    func applicationWillTerminate(_ notification: Notification) {
        sendTypingState(false)
        peerManager.stop()
        cloudRelay?.deactivate()
        quietHoursCheckTask?.cancel()
        cloudRelayActivationTask?.cancel()
    }

    // MARK: - Setup

    /// Builds the standard macOS main menu so windows respond to Cmd-Q,
    /// Cmd-W, Edit shortcuts, and the Help menu — even though this is an
    /// LSUIElement (menu-bar) app.
    private func setupMainMenu() {
        let mainMenu = NSMenu()

        // App menu
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(title: "About 1on1", action: #selector(showAboutFromMenu), keyEquivalent: ""))
        appMenu.addItem(NSMenuItem.separator())
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(showSettingsFromMenu), keyEquivalent: ",")
        settingsItem.target = self
        appMenu.addItem(settingsItem)
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(NSMenuItem(title: "Hide 1on1", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h"))
        let hideOthers = NSMenuItem(title: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(hideOthers)
        appMenu.addItem(NSMenuItem(title: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: ""))
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(NSMenuItem(title: "Quit 1on1", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        // Edit menu — gives text fields the standard cut/copy/paste/select-all + undo/redo
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z"))
        let redo = NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(redo)
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        // Window menu — Minimize, Zoom, Close
        let windowMenuItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(NSMenuItem(title: "Minimize", action: #selector(NSWindow.miniaturize(_:)), keyEquivalent: "m"))
        windowMenu.addItem(NSMenuItem(title: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: ""))
        windowMenu.addItem(NSMenuItem.separator())
        windowMenu.addItem(NSMenuItem(title: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w"))
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)
        NSApp.windowsMenu = windowMenu

        // Help menu — links to support page
        let helpMenuItem = NSMenuItem()
        let helpMenu = NSMenu(title: "Help")
        helpMenu.addItem(NSMenuItem(title: "1on1 Help", action: #selector(openHelp), keyEquivalent: "?"))
        helpMenuItem.submenu = helpMenu
        mainMenu.addItem(helpMenuItem)
        NSApp.helpMenu = helpMenu

        NSApp.mainMenu = mainMenu
    }

    @objc private func showAboutFromMenu() {
        if aboutWindowController == nil {
            aboutWindowController = AboutWindowController()
        }
        aboutWindowController?.showWindow()
    }

    @objc private func showSettingsFromMenu() {
        settingsWindowController?.showWindow()
    }

    @objc private func openHelp() {
        if let url = URL(string: "https://markstudios.com/1on1/support") {
            NSWorkspace.shared.open(url)
        }
    }

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
                    guard let self else { return }
                    do {
                        try self.databaseManager?.clearHistory()
                        self.appState.unreadCount = 0
                        self.appState.deliveryStatuses.removeAll()
                        self.appState.lastReadByPartner = nil
                        self.clearPersistedQuietHoursPendingIDs()
                        self.statusBar?.updateIcon()
                    } catch {
                        logger.error("Failed to clear history: \(error.localizedDescription)")
                    }
                }
            )
        } catch {
            logger.error("Failed to initialize database: \(error.localizedDescription)")
        }
    }

    private func setupTransportRouter() {
        let router = TransportRouter(peerManager: peerManager)
        router.onMessageReceived = { [weak self] message in
            self?.handleIncomingMessage(message)
        }
        router.onDeliveryStatusChanged = { [weak self] messageID, status in
            self?.appState.deliveryStatuses[messageID] = status
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

            // Until the partner sends presence, show whatever name we already
            // know — last known presence, or the peer's hostname as a last resort.
            if self.appState.partnerName.isEmpty {
                self.appState.partnerName = self.peerManager.partnerDisplayName ?? ""
            }
            self.statusBar.updateIcon()

            if status == .connected {
                self.transportRouter?.flushPendingQueue()
                self.broadcastPresence()
            }
        }
    }

    private func setupSettingsObservation() {
        settingsManager.onRoomCodeChanged = { [weak self] roomCode in
            Task { @MainActor [weak self] in
                self?.scheduleCloudRelayActivation(roomCode: roomCode)
            }
        }
        settingsManager.onMyDisplayNameChanged = { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.broadcastPresence()
            }
        }
    }

    private func setupStatusBar() {
        statusBar = StatusBarController(appState: appState)

        let composeView = ComposeView(
            appState: appState,
            settings: settingsManager,
            onSend: { [weak self] text in
                self?.sendTextMessage(text)
                self?.statusBar.togglePopover()
            },
            onTypingChanged: { [weak self] isTyping in
                self?.handleTypingChanged(isTyping)
            },
            onReconnect: { [weak self] in
                self?.retryConnections()
            },
            onShowSettings: { [weak self] in
                self?.statusBar.togglePopover()
                self?.settingsWindowController?.showWindow()
            },
            initialDraft: settingsManager.composeDraft,
            onDraftChanged: { [weak self] text in
                self?.settingsManager.composeDraft = text
            }
        )
        statusBar.setup(rootView: composeView)
        statusBar.updateIcon()
        statusBar.onShowHistory = { [weak self] in
            self?.conversationWindowController?.showWindow()
        }

        settingsWindowController = SettingsWindowController(settings: settingsManager)
        let openSettings: () -> Void = { [weak self] in
            self?.settingsWindowController?.showWindow()
        }
        statusBar.onShowSettings = openSettings
        statusBar.onShowAbout = { [weak self] in
            if self?.aboutWindowController == nil {
                self?.aboutWindowController = AboutWindowController()
            }
            self?.aboutWindowController?.showWindow()
        }
        statusBar.onUserActivity = { [weak self] in
            self?.cloudRelay?.bumpToActivePolling()
        }
        conversationWindowController?.onOpenSettings = openSettings
        conversationWindowController?.onDeleteMessage = { [weak self] id in
            try? self?.databaseManager?.deleteMessage(id: id)
        }
        conversationWindowController?.onResendMessage = { [weak self] id in
            self?.resendMessage(id: id)
        }
        conversationWindowController?.onReconnect = { [weak self] in
            self?.retryConnections()
        }
        conversationWindowController?.onMarkRead = { [weak self] in
            self?.markMessagesRead()
        }
    }

    private func setupOverlayManager() {
        overlayManager.onReply = { [weak self] text in
            self?.sendTextMessage(text)
        }
        overlayManager.settings = settingsManager
    }

    private func setupScreenshot() {
        screenshotManager.onScreenshotCaptured = { [weak self] imageData in
            guard let self else { return }
            let message = Message(
                senderName: self.settingsManager.myDisplayName,
                body: "Screenshot",
                type: .screenshot,
                isFromMe: true,
                attachmentData: imageData,
                attachmentMimeType: "image/jpeg"
            )
            let deliveryStatus = self.transportRouter?.send(message) ?? .queued
            self.appState.deliveryStatuses[message.id] = deliveryStatus
            _ = try? self.databaseManager?.save(message)
        }
        screenshotManager.onScreenshotFailed = { [weak self] message in
            self?.showScreenshotFailure(message)
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
        deliverQuietHoursQueueIfNeeded()

        quietHoursCheckTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard !Task.isCancelled, let self else { return }
                self.deliverQuietHoursQueueIfNeeded()
            }
        }
    }

    private func activateCloudRelayIfNeeded() {
        configureCloudRelay(roomCode: settingsManager.roomCode)
    }

    private func scheduleCloudRelayActivation(roomCode: String) {
        cloudRelayActivationTask?.cancel()
        cloudRelayActivationTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            self?.configureCloudRelay(roomCode: roomCode)
        }
    }

    private func configureCloudRelay(roomCode: String) {
        configureCloudRelay(roomCode: roomCode, force: false)
    }

    private func configureCloudRelay(roomCode: String, force: Bool) {
        let normalizedRoomCode = roomCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard force || normalizedRoomCode != activeRoomCode else { return }

        cloudRelay?.deactivate()
        cloudRelay = nil
        transportRouter?.cloudRelay = nil
        appState.isRelayActive = false
        activeRoomCode = ""
        statusBar.updateIcon()

        guard !normalizedRoomCode.isEmpty else { return }

        // Refuse to relay against the user's own handle — that creates a self-room
        // where presence pings echo back and waste CloudKit quota.
        if normalizedRoomCode.uppercased() == settingsManager.myHandle.uppercased() {
            return
        }

        let relay = CloudRelayManager()
        cloudRelay = relay
        transportRouter?.cloudRelay = relay

        Task { @MainActor [weak self, weak relay] in
            guard let relay else { return }
            await relay.activate(roomCode: normalizedRoomCode)
            guard let self, self.cloudRelay === relay else { return }

            self.appState.isRelayActive = relay.isActive
            self.statusBar.updateIcon()
            if relay.isActive {
                self.activeRoomCode = normalizedRoomCode
                self.transportRouter?.flushPendingQueue()
                self.broadcastPresence()
            } else {
                self.cloudRelay = nil
                self.transportRouter?.cloudRelay = nil
            }
        }
    }

    private func retryConnections() {
        peerManager.reconnectNow()
        configureCloudRelay(roomCode: settingsManager.roomCode, force: true)
    }

    // MARK: - Messaging

    private func handleIncomingMessage(_ message: Message) {
        // Handle control messages without saving or showing.
        switch message.type {
        case .typingStarted:
            appState.isPartnerTyping = true
            statusBar.updateIcon()
            return
        case .typingStopped:
            appState.isPartnerTyping = false
            statusBar.updateIcon()
            return
        case .readReceipt:
            appState.lastReadByPartner = message.timestamp
            return
        case .presence:
            updatePartnerName(from: message.body)
            return
        case .text, .screenshot:
            break
        }

        let isNewMessage: Bool
        if let databaseManager {
            isNewMessage = (try? databaseManager.save(message)) ?? false
        } else {
            isNewMessage = true
        }
        guard isNewMessage else { return }

        appState.unreadCount += 1
        statusBar.updateIcon()

        if settingsManager.isInQuietHours {
            queueQuietHoursMessage(message)
        } else {
            overlayManager.showMessage(message)
        }
    }

    private func sendTextMessage(_ text: String) {
        let message = Message(
            senderName: settingsManager.myDisplayName,
            body: text,
            type: .text,
            isFromMe: true
        )

        let deliveryStatus = transportRouter?.send(message) ?? .queued
        appState.deliveryStatuses[message.id] = deliveryStatus
        cloudRelay?.bumpToActivePolling()

        _ = try? databaseManager?.save(message)
    }

    private func broadcastPresence() {
        let name = settingsManager.myDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        guard peerManager.isConnected || cloudRelay?.isActive == true else { return }

        let message = Message(
            senderName: name,
            body: name,
            type: .presence,
            isFromMe: true
        )
        _ = transportRouter?.send(message)
    }

    private func updatePartnerName(from body: String) {
        let name = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        if appState.partnerName != name {
            appState.partnerName = name
        }
        if settingsManager.lastPartnerName != name {
            settingsManager.lastPartnerName = name
        }
    }

    private func resendMessage(id: UUID) {
        guard let message = appState.messages.first(where: { $0.id == id }),
              message.isFromMe else { return }
        let status = transportRouter?.retry(message) ?? .failed
        appState.deliveryStatuses[id] = status
    }

    private func sendReadReceipt() {
        guard peerManager.isConnected || cloudRelay?.isActive == true else { return }
        let message = Message(
            senderName: settingsManager.myDisplayName,
            body: "",
            type: .readReceipt,
            isFromMe: true
        )
        _ = transportRouter?.send(message)
    }

    private func markMessagesRead() {
        if appState.unreadCount > 0 {
            appState.unreadCount = 0
            quietHoursQueue.removeAll()
            clearPersistedQuietHoursPendingIDs()
            statusBar.updateIcon()
        }
        sendReadReceipt()
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
        guard peerManager.isConnected || cloudRelay?.isActive == true else { return }
        let message = Message(
            senderName: settingsManager.myDisplayName,
            body: "",
            type: isTyping ? .typingStarted : .typingStopped,
            isFromMe: true
        )
        _ = transportRouter?.send(message)
    }

    private func showScreenshotFailure(_ message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Screenshot Not Captured"
        alert.informativeText = "\(message)\n\nEnable Screen Recording for 1on1 in System Settings, then try Cmd+Shift+2 again."
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    private func queueQuietHoursMessage(_ message: Message) {
        quietHoursQueue.append(message)

        var pendingIDs = persistedQuietHoursPendingIDs()
        if !pendingIDs.contains(message.id) {
            pendingIDs.append(message.id)
            persistQuietHoursPendingIDs(pendingIDs)
        }
    }

    private func deliverQuietHoursQueueIfNeeded() {
        guard !settingsManager.isInQuietHours else { return }

        let queuedMessages = pendingQuietHoursMessages()
        guard !queuedMessages.isEmpty else { return }

        quietHoursQueue.removeAll()
        clearPersistedQuietHoursPendingIDs()

        for message in queuedMessages {
            overlayManager.showMessage(message)
        }
    }

    private func pendingQuietHoursMessages() -> [Message] {
        var messages = quietHoursQueue
        var seenIDs = Set(messages.map(\.id))

        for id in persistedQuietHoursPendingIDs() where !seenIDs.contains(id) {
            guard let message = appState.messages.first(where: { $0.id == id }) else { continue }
            messages.append(message)
            seenIDs.insert(id)
        }

        return messages.filter { !$0.isFromMe }
    }

    private func persistedQuietHoursPendingIDs() -> [UUID] {
        UserDefaults.standard
            .stringArray(forKey: Self.quietHoursPendingIDsKey)?
            .compactMap(UUID.init(uuidString:)) ?? []
    }

    private func persistQuietHoursPendingIDs(_ ids: [UUID]) {
        UserDefaults.standard.set(ids.map(\.uuidString), forKey: Self.quietHoursPendingIDsKey)
    }

    private func clearPersistedQuietHoursPendingIDs() {
        UserDefaults.standard.removeObject(forKey: Self.quietHoursPendingIDsKey)
    }
}
