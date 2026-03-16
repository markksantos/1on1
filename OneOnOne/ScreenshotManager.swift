import AppKit
import ScreenCaptureKit
import os

private let logger = Logger(subsystem: "com.markstudios.OneOnOne", category: "Screenshot")

@MainActor
final class ScreenshotManager {
    var onScreenshotCaptured: ((NSImage) -> Void)?

    func captureScreen() {
        Task {
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                guard let display = content.displays.first else {
                    logger.warning("No display found")
                    return
                }

                let filter = SCContentFilter(display: display, excludingWindows: [])
                let config = SCStreamConfiguration()
                config.width = Int(display.width)
                config.height = Int(display.height)
                config.pixelFormat = kCVPixelFormatType_32BGRA

                let image = try await SCScreenshotManager.captureImage(
                    contentFilter: filter,
                    configuration: config
                )

                let nsImage = NSImage(cgImage: image, size: NSSize(width: display.width, height: display.height))
                onScreenshotCaptured?(nsImage)
                logger.info("Screenshot captured: \(display.width)x\(display.height)")
            } catch {
                logger.error("Screenshot failed: \(error.localizedDescription)")
            }
        }
    }
}
