import AppKit
import SwiftUI
import OneOnOneEngine
import OneOnOneUI

@MainActor
final class OverlayStackManager {
    private var activePanels: [(panel: MessageOverlayPanel, message: Message, height: CGFloat)] = []
    private var pulseTimers: [UUID: Timer] = [:]
    private var autoDismissTimers: [UUID: Timer] = [:]
    private let overlaySpacing: CGFloat = 12

    var onReply: ((String) -> Void)?
    var settings: SettingsManager?

    private var overlayWidth: CGFloat {
        settings?.overlaySize.panelWidth ?? 420
    }

    func showMessage(_ message: Message) {
        if settings?.soundEnabled != false {
            playSound()
        }

        guard let screen = NSScreen.main else { return }

        let hostingView = NSHostingView(
            rootView: MessageOverlayView(
                message: message,
                panelWidth: overlayWidth,
                onReply: { [weak self] text in
                    self?.onReply?(text)
                },
                onDismiss: { [weak self] in
                    self?.dismissPanel(for: message.id)
                }
            )
        )
        hostingView.layer?.backgroundColor = .clear

        // The SwiftUI content is width-pinned to overlayWidth but its height is
        // dynamic (message length, screenshot, expanded reply field). Measure the
        // actual fitting height instead of guessing — a hardcoded height clips
        // long messages or leaves a tall empty panel for short ones.
        let fittingHeight = hostingView.fittingSize.height
        let panelHeight = fittingHeight > 0 ? fittingHeight : overlayHeight(for: message)

        let panel = MessageOverlayPanel(
            contentRect: NSRect(x: 0, y: 0, width: overlayWidth, height: panelHeight)
        )
        panel.contentView = hostingView

        // Position: center horizontally, upper-center vertically
        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - overlayWidth / 2
        let baseY = screenFrame.maxY - panelHeight - 80

        // Shift existing panels down
        shiftExistingPanels(downBy: panelHeight + overlaySpacing)

        panel.setFrameOrigin(NSPoint(x: x, y: baseY))
        activePanels.insert((panel: panel, message: message, height: panelHeight), at: 0)
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

    private func overlayHeight(for message: Message) -> CGFloat {
        if message.type == .screenshot, message.attachmentData != nil {
            return 400
        }
        return 220
    }

    private func shiftExistingPanels(downBy offset: CGFloat) {
        for entry in activePanels {
            var frame = entry.panel.frame
            frame.origin.y -= offset
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
        var nextTopY = screenFrame.maxY - 80

        for entry in activePanels {
            let y = nextTopY - entry.height
            var frame = entry.panel.frame
            frame.origin.y = y
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.25
                ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                entry.panel.animator().setFrame(frame, display: true)
            }
            nextTopY = y - overlaySpacing
        }
    }

    // MARK: - Pulse & Sound

    private func startPulseTimer(for messageID: UUID, panel: MessageOverlayPanel) {
        let timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak panel] _ in
            Task { @MainActor [weak panel] in
                guard let panel else { return }
                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 0.12
                    panel.animator().alphaValue = 0.6
                } completionHandler: {
                    Task { @MainActor [weak panel] in
                        guard let panel else { return }
                        NSAnimationContext.runAnimationGroup { ctx in
                            ctx.duration = 0.12
                            panel.animator().alphaValue = 1.0
                        }
                    }
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
