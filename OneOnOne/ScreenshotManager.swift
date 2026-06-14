import AppKit
import CoreGraphics
import ScreenCaptureKit
import os

private let logger = Logger(subsystem: "com.markstudios.OneOnOne", category: "Screenshot")

@MainActor
final class ScreenshotManager {
    private static let maxScreenshotBytes = 750_000

    var onScreenshotCaptured: ((Data) -> Void)?
    var onScreenshotFailed: ((String) -> Void)?

    func captureScreen() {
        guard CGPreflightScreenCaptureAccess() else {
            if CGRequestScreenCaptureAccess() {
                captureScreen()
            } else {
                notifyFailure("Screen Recording permission is required to capture screenshots.")
            }
            return
        }

        Task {
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                guard let display = content.displays.first else {
                    notifyFailure("No display was available to capture.")
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

                guard let imageData = Self.compressedJPEGData(from: image) else {
                    notifyFailure("Screenshot compression failed.")
                    return
                }

                onScreenshotCaptured?(imageData)
                logger.info("Screenshot captured: \(display.width)x\(display.height), \(imageData.count) bytes")
            } catch {
                notifyFailure("Screenshot failed: \(error.localizedDescription)")
            }
        }
    }

    private func notifyFailure(_ message: String) {
        logger.error("\(message)")
        onScreenshotFailed?(message)
    }

    private static func compressedJPEGData(
        from image: CGImage,
        maxPixelDimension: CGFloat = 1600,
        compression: CGFloat = 0.75
    ) -> Data? {
        let dimensions: [CGFloat] = [
            maxPixelDimension,
            min(1280, maxPixelDimension),
            min(960, maxPixelDimension),
            min(720, maxPixelDimension),
        ]
        let compressionLevels: [CGFloat] = [compression, 0.6, 0.45]
        var smallestData: Data?

        for dimension in dimensions {
            for compressionLevel in compressionLevels {
                guard let data = jpegData(
                    from: image,
                    maxPixelDimension: dimension,
                    compression: compressionLevel
                ) else { continue }

                if data.count <= Self.maxScreenshotBytes {
                    return data
                }
                if smallestData == nil || data.count < smallestData!.count {
                    smallestData = data
                }
            }
        }

        return smallestData
    }

    private static func jpegData(
        from image: CGImage,
        maxPixelDimension: CGFloat,
        compression: CGFloat
    ) -> Data? {
        let sourceSize = NSSize(width: image.width, height: image.height)
        let largestDimension = max(sourceSize.width, sourceSize.height)
        let scale = min(1, maxPixelDimension / largestDimension)
        let targetSize = NSSize(width: sourceSize.width * scale, height: sourceSize.height * scale)

        let resizedImage = NSImage(size: targetSize)
        resizedImage.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        NSImage(cgImage: image, size: sourceSize).draw(in: NSRect(origin: .zero, size: targetSize))
        resizedImage.unlockFocus()

        guard let tiffData = resizedImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }

        return bitmap.representation(
            using: .jpeg,
            properties: [.compressionFactor: compression]
        )
    }
}
