import AppKit
import SwiftUI
import OneOnOneEngine
import OneOnOneUI

@MainActor
final class OverlayStackManager {
    private var activePanels: [(panel: MessageOverlayPanel, message: Message)] = []
    private var pulseTimers: [UUID: Timer] = [:]
    private var autoDismissTimers: [UUID: Timer] = [:]
    private let overlaySpacing: CGFloat = 12

    var onReply: ((String) -> Void)?
    var settings: SettingsManager?

    private var overlayWidth: CGFloat {
        settings?.overlaySize.panelWidth ?? 420
    }

    private var overlayHeight: CGFloat { 220 }

    func showMessage(_ message: Message) {
        if settings?.soundEnabled != false {
            playSound()
        }

        guard let screen = NSScreen.main else { return }

        let panel = MessageOverlayPanel(
            contentRect: NSRect(x: 0, y: 0, width: overlayWidth, height: overlayHeight)
        )

        let hostingView = NSHostingView(
            rootView: MessageOverlayView(
                message: message,
                onReply: { [weak self] text in
                    self?.onReply?(text)
                },
                onDismiss: { [weak self] in
                    self?.dismissPanel(for: message.id)
                }
            )
        )
        hostingView.layer?.backgroundColor = .clear
        panel.contentView = hostingView

        // Position: center horizontally, upper-center vertically
        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - overlayWidth / 2
        let baseY = screenFrame.maxY - overlayHeight - 80

        // Shift existing panels down
        shiftExistingPanels()

        panel.setFrameOrigin(NSPoint(x: x, y: baseY))
        activePanels.insert((panel: panel, message: message), at: 0)
        panel.fadeIn()

        startPulseTimer(for: message.id, panel: panel)
        startAutoDismissTimer(for: message.id)
    }

    func dismissPanel(for messageID: UUID) {
        guard let index = activePanels.firstIndex(where: { $0.message.id == messageID }) else { return }
        let entry = activePanels[index]
        pulseTimers[messageID]?.invalidate()
        pulseTimers.removeValue(forKey: messageID)
        autoDismissTimers[messageID]?.invalidate()
        autoDismissTimers.removeValue(forKey: messageID)

        entry.panel.fadeOut { [weak self] in
            self?.activePanels.removeAll { $0.message.id == messageID }
            self?.relayoutPanels()
        }
    }

    func dismissAll() {
        for entry in activePanels {
            pulseTimers[entry.message.id]?.invalidate()
            autoDismissTimers[entry.message.id]?.invalidate()
            entry.panel.fadeOut {}
        }
        pulseTimers.removeAll()
        autoDismissTimers.removeAll()
        activePanels.removeAll()
    }

    // MARK: - Layout

    private func shiftExistingPanels() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let baseY = screenFrame.maxY - overlayHeight - 80

        for (i, entry) in activePanels.enumerated() {
            let y = baseY - CGFloat(i + 1) * (overlayHeight + overlaySpacing)
            var frame = entry.panel.frame
            frame.origin.y = y
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.25
                ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                entry.panel.animator().setFrame(frame, display: true)
            }
        }
    }

    private func relayoutPanels() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let baseY = screenFrame.maxY - overlayHeight - 80

        for (i, entry) in activePanels.enumerated() {
            let y = baseY - CGFloat(i) * (overlayHeight + overlaySpacing)
            var frame = entry.panel.frame
            frame.origin.y = y
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.25
                ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                entry.panel.animator().setFrame(frame, display: true)
            }
        }
    }

    // MARK: - Pulse & Sound

    private func startPulseTimer(for messageID: UUID, panel: MessageOverlayPanel) {
        let timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak panel] _ in
            guard let panel else { return }
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.12
                panel.animator().alphaValue = 0.6
            } completionHandler: {
                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 0.12
                    panel.animator().alphaValue = 1.0
                }
            }
        }
        pulseTimers[messageID] = timer
    }

    private func startAutoDismissTimer(for messageID: UUID) {
        let timeout = settings?.overlayTimeout ?? 300
        guard timeout > 0 else { return }
        let timer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.dismissPanel(for: messageID)
            }
        }
        autoDismissTimers[messageID] = timer
    }

    private func playSound() {
        // Use built-in macOS system sound
        NSSound(named: "Blow")?.play()
    }
}
