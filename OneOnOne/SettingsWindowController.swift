import AppKit
import SwiftUI
import OneOnOneEngine
import OneOnOneUI

@MainActor
final class SettingsWindowController {
    private var window: NSWindow?
    private let settings: SettingsManager

    init(settings: SettingsManager) {
        self.settings = settings
    }

    func showWindow() {
        if let window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            return
        }

        let settingsView = SettingsView(settings: settings)
        let hostingView = NSHostingView(rootView: settingsView)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 500),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "1on1 — Settings"
        window.contentView = hostingView
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.window = window
    }
}
