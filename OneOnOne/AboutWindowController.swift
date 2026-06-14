import AppKit
import SwiftUI
import OneOnOneUI

@MainActor
final class AboutWindowController {
    private static let privacyURL = URL(string: "https://markstudios.com/1on1/privacy")!
    private static let supportURL = URL(string: "https://markstudios.com/1on1/support")!
    private static let feedbackEmail = "hello@markstudios.com"

    private var window: NSWindow?

    func showWindow() {
        if let window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let info = Bundle.main.infoDictionary ?? [:]
        let version = info["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = info["CFBundleVersion"] as? String ?? "1"
        let copyright = info["NSHumanReadableCopyright"] as? String
            ?? "Copyright © Mark Studios LLC."

        let view = AboutView(
            version: version,
            buildNumber: build,
            copyright: copyright,
            onOpenPrivacy: { NSWorkspace.shared.open(Self.privacyURL) },
            onOpenSupport: { NSWorkspace.shared.open(Self.supportURL) },
            onSendFeedback: {
                let subject = "1on1 \(version) (\(build)) — Feedback"
                guard let encoded = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                      let url = URL(string: "mailto:\(Self.feedbackEmail)?subject=\(encoded)") else { return }
                NSWorkspace.shared.open(url)
            }
        )

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 380),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "About 1on1"
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: view)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }
}
