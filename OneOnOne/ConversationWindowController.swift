import AppKit
import SwiftUI
import OneOnOneEngine
import OneOnOneUI

@MainActor
final class ConversationWindowController {
    private var window: NSWindow?
    private let databaseManager: DatabaseManager

    init(databaseManager: DatabaseManager) {
        self.databaseManager = databaseManager
    }

    func showWindow() {
        if let window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            return
        }

        let conversationView = ConversationView(
            messages: databaseManager.messages,
            onClearHistory: { [weak self] in
                try? self?.databaseManager.clearHistory()
            }
        )

        let hostingView = NSHostingView(rootView: conversationView)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 600),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "1on1 — History"
        window.contentView = hostingView
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.window = window
    }
}
