import AppKit
import SwiftUI

public struct AboutView: View {
    let version: String
    let buildNumber: String
    let copyright: String
    let onOpenPrivacy: () -> Void
    let onOpenSupport: () -> Void
    let onSendFeedback: () -> Void

    public init(
        version: String,
        buildNumber: String,
        copyright: String,
        onOpenPrivacy: @escaping () -> Void,
        onOpenSupport: @escaping () -> Void,
        onSendFeedback: @escaping () -> Void
    ) {
        self.version = version
        self.buildNumber = buildNumber
        self.copyright = copyright
        self.onOpenPrivacy = onOpenPrivacy
        self.onOpenSupport = onOpenSupport
        self.onSendFeedback = onSendFeedback
    }

    public var body: some View {
        VStack(spacing: 18) {
            appIcon
                .padding(.top, 28)

            VStack(spacing: 4) {
                Text("1on1")
                    .font(.system(size: 22, weight: .semibold))
                Text("Version \(version) (\(buildNumber))")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Text("Direct messages that demand attention.\nBuilt for two.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Divider().padding(.horizontal, 40)

            VStack(spacing: 8) {
                linkButton("Privacy Policy", systemImage: "hand.raised", action: onOpenPrivacy)
                linkButton("Support", systemImage: "lifepreserver", action: onOpenSupport)
                linkButton("Send Feedback", systemImage: "envelope", action: onSendFeedback)
            }

            Spacer()

            Text(copyright)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .padding(.bottom, 16)
        }
        .frame(width: 320, height: 380)
    }

    private var appIcon: some View {
        Group {
            if let image = NSImage(named: "AppIcon") {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 96, height: 96)
            } else {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.blue)
            }
        }
    }

    private func linkButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: systemImage)
                    .frame(width: 18)
                Text(title)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            .font(.system(size: 13))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(.quinary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 32)
    }
}
