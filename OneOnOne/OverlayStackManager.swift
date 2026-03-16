import AppKit
import SwiftUI
import OneOnOneEngine
import OneOnOneUI

@Observable
@MainActor
final class OverlayStackManager {
    private var activePanels: [(panel: MessageOverlayPanel, message: Message)] = []
    private var pulseTimers: [UUID: Timer] = [:]
    private let overlaySpacing: CGFloat = 16

    var onReply: ((String) -> Void)?
    var settings: SettingsManager?

    private var overlayWidth: CGFloat {
        settings?.overlaySize.panelWidth ?? 440
    }

    private var overlayHeight: CGFloat { 260 }

    func showMessage(_ message: Message) {
        if settings?.soundEnabled != false {
            playReceiveSound()
        }

        guard let screen = NSScreen.main else { return }
        let width = overlayWidth

        let panel = MessageOverlayPanel(contentRect: NSRect(x: 0, y: 0, width: width, height: overlayHeight))

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
        panel.contentView = hostingView

        // Center on screen
        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - width / 2
        let y = screenFrame.midY - overlayHeight / 2
        panel.setFrameOrigin(NSPoint(x: x, y: y))

        // Shift existing panels up
        shiftPanelsUp()

        activePanels.append((panel: panel, message: message))
        panel.orderFrontRegardless()

        // 30-second pulse timer
        startPulseTimer(for: message.id, panel: panel)
    }

    func dismissPanel(for messageID: UUID) {
        guard let index = activePanels.firstIndex(where: { $0.message.id == messageID }) else { return }
        let entry = activePanels[index]
        pulseTimers[messageID]?.invalidate()
        pulseTimers.removeValue(forKey: messageID)

        entry.panel.fadeOut { [weak self] in
            self?.activePanels.removeAll { $0.message.id == messageID }
            self?.recenterPanels()
        }
    }

    func dismissAll() {
        for entry in activePanels {
            pulseTimers[entry.message.id]?.invalidate()
            entry.panel.fadeOut {}
        }
        pulseTimers.removeAll()
        activePanels.removeAll()
    }

    // MARK: - Private

    private func shiftPanelsUp() {
        for (i, entry) in activePanels.enumerated() {
            let offset = CGFloat(activePanels.count - i) * (overlayHeight + overlaySpacing)
            var frame = entry.panel.frame
            if let screen = NSScreen.main {
                frame.origin.y = screen.visibleFrame.midY - overlayHeight / 2 + offset
            }
            entry.panel.setFrame(frame, display: true, animate: true)
        }
    }

    private func recenterPanels() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame

        for (i, entry) in activePanels.enumerated() {
            let totalHeight = CGFloat(activePanels.count) * (overlayHeight + overlaySpacing) - overlaySpacing
            let baseY = screenFrame.midY - totalHeight / 2
            let y = baseY + CGFloat(activePanels.count - 1 - i) * (overlayHeight + overlaySpacing)
            var frame = entry.panel.frame
            frame.origin.y = y
            entry.panel.setFrame(frame, display: true, animate: true)
        }
    }

    private func startPulseTimer(for messageID: UUID, panel: MessageOverlayPanel) {
        let timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak panel] _ in
            guard let panel else { return }
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.15
                panel.animator().alphaValue = 0.7
            } completionHandler: {
                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 0.15
                    panel.animator().alphaValue = 1.0
                }
            }
        }
        pulseTimers[messageID] = timer
    }

    private func playReceiveSound() {
        NSSound(named: "Pop")?.play()
    }
}
