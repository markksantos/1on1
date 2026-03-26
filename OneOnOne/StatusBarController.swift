import AppKit
import SwiftUI
import OneOnOneEngine

@MainActor
final class StatusBarController: NSObject {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!

    var onShowHistory: (() -> Void)?
    var onShowSettings: (() -> Void)?

    private let appState: AppState

    init(appState: AppState) {
        self.appState = appState
        super.init()
    }

    func setup(composeView: NSView) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            setTemplateImage("bubble.left.and.bubble.right", on: button)
            button.action = #selector(handleClick(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        popover = NSPopover()
        popover.contentSize = NSSize(width: 300, height: 120)
        popover.behavior = .semitransient
        popover.animates = true
        popover.contentViewController = NSViewController()
        popover.contentViewController?.view = composeView
    }

    func updateIcon() {
        guard let button = statusItem?.button else { return }

        // Use distinct symbols for each state — template images adapt to menu bar appearance
        let symbolName: String
        if appState.isPartnerTyping {
            symbolName = "ellipsis.bubble"
        } else if appState.unreadCount > 0 {
            symbolName = "exclamationmark.bubble"
        } else {
            switch appState.connectionStatus {
            case .connected:
                symbolName = "bubble.left.and.bubble.right.fill"
            case .connecting, .reconnecting:
                symbolName = "bubble.left.and.bubble.right"
            case .offline:
                symbolName = "bubble.left.and.bubble.right"
            }
        }

        setTemplateImage(symbolName, on: button)
    }

    @objc func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            appState.unreadCount = 0
            updateIcon()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    // MARK: - Private

    private func setTemplateImage(_ symbolName: String, on button: NSStatusBarButton) {
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "1on1")
        image?.isTemplate = true
        button.image = image
    }

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else {
            togglePopover()
            return
        }
        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    @objc private func showHistory() { onShowHistory?() }
    @objc private func showSettings() { onShowSettings?() }

    private func showContextMenu() {
        let menu = NSMenu()

        let historyItem = NSMenuItem(title: "Message History", action: #selector(showHistory), keyEquivalent: "h")
        historyItem.target = self
        menu.addItem(historyItem)

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let statusText: String
        switch appState.connectionStatus {
        case .connected: statusText = "Connected to \(appState.partnerName)"
        case .connecting: statusText = "Connecting…"
        case .reconnecting: statusText = "Reconnecting…"
        case .offline: statusText = "Offline"
        }
        let statusItem = NSMenuItem(title: statusText, action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit 1on1", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        self.statusItem.menu = menu
        self.statusItem.button?.performClick(nil)
        self.statusItem.menu = nil
    }
}
