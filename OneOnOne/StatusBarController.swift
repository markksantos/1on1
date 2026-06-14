import AppKit
import SwiftUI
import OneOnOneEngine

@MainActor
final class StatusBarController: NSObject {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!

    var onShowHistory: (() -> Void)?
    var onShowSettings: (() -> Void)?
    var onShowAbout: (() -> Void)?
    var onUserActivity: (() -> Void)?
    var onMarkRead: (() -> Void)?

    private let appState: AppState

    init(appState: AppState) {
        self.appState = appState
        super.init()
    }

    /// Sets up the status item and the popover. The hosting controller manages
    /// SwiftUI lifecycle and auto-sizes the popover to fit the current content.
    func setup<V: View>(rootView: V) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            updateIcon(on: button)
            button.action = #selector(handleClick(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        let hostingController = NSHostingController(rootView: rootView)
        hostingController.sizingOptions = [.preferredContentSize]

        popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = hostingController
    }

    func updateIcon() {
        guard let button = statusItem?.button else { return }
        updateIcon(on: button)
    }

    @objc func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            // Opening the popover counts as reading: clear the badge, flush the
            // quiet-hours queue, and send a read receipt — all owned by the
            // AppDelegate's mark-read path so this matches the history window.
            // Falling back to a direct reset keeps the badge correct even if no
            // handler is wired.
            if let onMarkRead {
                onMarkRead()
            } else {
                appState.unreadCount = 0
            }
            updateIcon()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
            NSApp.activate(ignoringOtherApps: true)
            onUserActivity?()
        }
    }

    // MARK: - Icon

    /// Filled SF Symbols render with more visual weight in the menu bar than thin
    /// outlines, which can disappear against dark wallpapers.
    private func updateIcon(on button: NSStatusBarButton) {
        let symbolName: String
        if appState.isPartnerTyping {
            symbolName = "ellipsis.message.fill"
        } else if appState.unreadCount > 0 {
            symbolName = "exclamationmark.message.fill"
        } else {
            switch appState.connectionStatus {
            case .connected:
                symbolName = "bubble.left.and.bubble.right.fill"
            case .connecting, .reconnecting:
                symbolName = appState.isRelayActive ? "icloud.fill" : "bubble.left.and.bubble.right.fill"
            case .offline:
                symbolName = appState.isRelayActive ? "icloud.fill" : "bubble.left.and.bubble.right.fill"
            }
        }

        let config = NSImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "1on1")?
            .withSymbolConfiguration(config)
        image?.isTemplate = true
        button.image = image
        button.contentTintColor = statusTintColor
        button.appearsDisabled = false
        button.toolTip = currentTooltip
    }

    private var currentTooltip: String {
        let partner = appState.partnerName.trimmingCharacters(in: .whitespacesAndNewlines)
        let unread = appState.unreadCount > 0 ? " · \(appState.unreadCount) unread" : ""
        let state: String
        switch appState.connectionStatus {
        case .connected:
            state = partner.isEmpty ? "Connected" : "Connected to \(partner)"
        case .connecting:
            state = "Connecting…"
        case .reconnecting:
            state = appState.isRelayActive ? "Relay ready" : "Reconnecting…"
        case .offline:
            state = appState.isRelayActive ? "Relay ready" : "Waiting for partner"
        }
        return "1on1 — \(state)\(unread)"
    }

    /// Returns a tint only when conveying real status. Returning nil lets the
    /// menu bar render the template image with its own foreground color, which
    /// adapts to dark/light backgrounds correctly.
    private var statusTintColor: NSColor? {
        if appState.unreadCount > 0 {
            return .systemRed
        }
        if appState.isPartnerTyping {
            return .systemBlue
        }

        switch appState.connectionStatus {
        case .connected:
            return .systemGreen
        case .connecting, .reconnecting:
            return appState.isRelayActive ? .systemBlue : nil
        case .offline:
            return appState.isRelayActive ? .systemBlue : nil
        }
    }

    // MARK: - Click handling

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
    @objc private func showAbout() { onShowAbout?() }

    private func showContextMenu() {
        let menu = NSMenu()

        let historyItem = NSMenuItem(title: "Message History", action: #selector(showHistory), keyEquivalent: "h")
        historyItem.target = self
        menu.addItem(historyItem)

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let aboutItem = NSMenuItem(title: "About 1on1", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        let statusText: String
        let partnerName = appState.partnerName.trimmingCharacters(in: .whitespacesAndNewlines)
        switch appState.connectionStatus {
        case .connected:
            statusText = partnerName.isEmpty ? "Connected" : "Connected to \(partnerName)"
        case .connecting:
            statusText = "Connecting…"
        case .reconnecting:
            statusText = appState.isRelayActive ? "Relay Ready" : "Reconnecting…"
        case .offline:
            statusText = appState.isRelayActive ? "Relay Ready" : "Waiting for partner…"
        }
        let statusMenuItem = NSMenuItem(title: statusText, action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit 1on1", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        self.statusItem.menu = menu
        self.statusItem.button?.performClick(nil)
        self.statusItem.menu = nil
    }
}
