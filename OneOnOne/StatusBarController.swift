import AppKit
import SwiftUI
import OneOnOneUI

@MainActor
final class StatusBarController {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!

    var onShowHistory: (() -> Void)?
    var onShowSettings: (() -> Void)?

    var isConnected: Bool = false {
        didSet { updateIcon() }
    }

    var hasUnread: Bool = false {
        didSet { updateIcon() }
    }

    var isPartnerTyping: Bool = false {
        didSet { updateIcon() }
    }

    func setup(composeView: NSView) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "bubble.left.and.bubble.right.fill", accessibilityDescription: "1on1")
            button.action = #selector(handleClick(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 100)
        popover.behavior = .transient
        popover.contentViewController = NSViewController()
        popover.contentViewController?.view = composeView
    }

    @objc func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            hasUnread = false
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
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

    @objc private func showHistory() {
        onShowHistory?()
    }

    @objc private func showSettings() {
        onShowSettings?()
    }

    private func showContextMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "View History", action: #selector(showHistory), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: ","))
        menu.items.forEach { $0.target = self }
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit 1on1", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    private func updateIcon() {
        guard let button = statusItem?.button else { return }
        let symbolName: String
        if isPartnerTyping {
            symbolName = "ellipsis.bubble.fill"
        } else if hasUnread {
            symbolName = "bubble.left.and.exclamationmark.bubble.right.fill"
        } else if isConnected {
            symbolName = "bubble.left.and.bubble.right.fill"
        } else {
            symbolName = "bubble.left.and.bubble.right"
        }
        button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "1on1")

        if isPartnerTyping {
            button.contentTintColor = .systemOrange
        } else if hasUnread {
            button.contentTintColor = .systemBlue
        } else if isConnected {
            button.contentTintColor = .systemGreen
        } else {
            button.contentTintColor = .secondaryLabelColor
        }
    }
}
