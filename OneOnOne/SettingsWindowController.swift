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
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = SettingsView(settings: settings)
        let hostingView = NSHostingView(rootView: view)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 360),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "1on1 Settings"
        window.contentView = hostingView
        window.setFrameAutosaveName("SettingsWindow")
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }
}
