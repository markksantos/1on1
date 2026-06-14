import AppKit
import SwiftUI
import OneOnOneEngine
import OneOnOneUI

@MainActor
final class WelcomeWindowController {
    private var window: NSWindow?
    private let settings: SettingsManager

    init(settings: SettingsManager) {
        self.settings = settings
    }

    func showIfNeeded() {
        guard !settings.hasCompletedOnboarding else { return }
        showWindow()
    }

    func showWindow() {
        if let window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 480),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Welcome to 1on1"
        window.isReleasedWhenClosed = false
        window.center()

        let view = WelcomeView(settings: settings) { [weak self] in
            self?.window?.close()
            self?.window = nil
        }
        window.contentView = NSHostingView(rootView: view)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.window = window
    }
}
