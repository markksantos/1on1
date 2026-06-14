import AppKit
import SwiftUI
import OneOnOneEngine
import OneOnOneUI

@MainActor
final class ConversationWindowController {
    private var window: NSWindow?
    private let appState: AppState
    private let onClearHistory: () -> Void
    var onOpenSettings: (() -> Void)?
    var onDeleteMessage: ((UUID) -> Void)?
    var onResendMessage: ((UUID) -> Void)?
    var onReconnect: (() -> Void)?
    var onMarkRead: (() -> Void)?

    init(appState: AppState, onClearHistory: @escaping () -> Void) {
        self.appState = appState
        self.onClearHistory = onClearHistory
    }

    func showWindow() {
        if let window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = ConversationView(
            appState: appState,
            onClearHistory: onClearHistory,
            onOpenSettings: { [weak self] in self?.onOpenSettings?() },
            onDeleteMessage: { [weak self] id in self?.onDeleteMessage?(id) },
            onResendMessage: { [weak self] id in self?.onResendMessage?(id) },
            onReconnect: { [weak self] in self?.onReconnect?() },
            onMarkRead: { [weak self] in self?.onMarkRead?() }
        )
        let hostingView = NSHostingView(rootView: view)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 600),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "1on1"
        window.subtitle = "Message History"
        window.contentView = hostingView
        window.contentMinSize = NSSize(width: 360, height: 400)
        window.setFrameAutosaveName("ConversationWindow")
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }
}
