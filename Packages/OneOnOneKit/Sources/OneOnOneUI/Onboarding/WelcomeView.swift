import AppKit
import SwiftUI
import OneOnOneEngine

public struct WelcomeView: View {
    @Bindable var settings: SettingsManager
    let onFinish: () -> Void

    @State private var page: Page = .intro
    @State private var displayNameDraft: String

    public init(settings: SettingsManager, onFinish: @escaping () -> Void) {
        self.settings = settings
        self.onFinish = onFinish
        self._displayNameDraft = State(initialValue: settings.myDisplayName)
    }

    enum Page: Hashable { case intro, identity, invite }

    public var body: some View {
        VStack(spacing: 0) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 32)
                .padding(.top, 36)

            Divider()

            footer
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
        }
        .frame(width: 520, height: 480)
    }

    // MARK: - Pages

    @ViewBuilder
    private var content: some View {
        switch page {
        case .intro: introPage
        case .identity: identityPage
        case .invite: invitePage
        }
    }

    private var introPage: some View {
        VStack(spacing: 18) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 64))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.blue)

            Text("Welcome to 1on1")
                .font(.system(size: 26, weight: .semibold))

            Text("Direct messages that demand attention.\nBuilt for two people who want to actually hear from each other.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 12) {
                feature("Floating overlays", "Messages appear as unmissable panels in the center of your screen.", icon: "rectangle.center.inset.filled")
                feature("Stays in your menu bar", "Always one click away. Cmd-Shift-1 to compose, Cmd-Shift-2 to share a screenshot.", icon: "menubar.rectangle")
                feature("Encrypted, peer-to-peer", "Local network when you're nearby. End-to-end encrypted relay over the internet otherwise.", icon: "lock.shield")
            }
            .padding(.top, 6)
            .frame(maxWidth: 420)
        }
    }

    private var identityPage: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Pick a display name")
                .font(.system(size: 22, weight: .semibold))

            Text("This is the name your partner will see when you message them. You can change it later in Settings.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

            TextField("Display Name", text: $displayNameDraft)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 14))
                .onSubmit { advance() }
        }
        .frame(maxWidth: 420)
        .padding(.top, 24)
    }

    private var invitePage: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Share your code")
                .font(.system(size: 22, weight: .semibold))

            Text("This code is unique to you. Send it to your partner — they'll paste it into their Connection settings to start messaging you.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                Text("Your code")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                HStack(spacing: 8) {
                    Text(settings.myHandle)
                        .font(.system(size: 18, weight: .medium, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(settings.myHandle, forType: .string)
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                }
                .padding(14)
                .background(.quinary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            Text("Once your partner enters this code, you'll see their name appear automatically. You can also enter their code on the Connection tab to message them first.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
        .frame(maxWidth: 420)
    }

    private func feature(_ title: String, _ subtitle: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(.blue)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .semibold))
                Text(subtitle).font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            pageDots
            Spacer()
            if page != .intro {
                Button("Back") { back() }
                    .buttonStyle(.bordered)
            }
            Button(primaryButtonTitle) { advance() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: [])
                .disabled(primaryButtonDisabled)
        }
    }

    private var pageDots: some View {
        HStack(spacing: 6) {
            ForEach([Page.intro, .identity, .invite], id: \.self) { p in
                Circle()
                    .fill(page == p ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: 7, height: 7)
            }
        }
    }

    private var primaryButtonTitle: String {
        switch page {
        case .intro: "Get Started"
        case .identity: "Next"
        case .invite: "Done"
        }
    }

    private var primaryButtonDisabled: Bool {
        if page == .identity {
            return displayNameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return false
    }

    private func advance() {
        switch page {
        case .intro:
            page = .identity
        case .identity:
            let trimmed = displayNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { settings.myDisplayName = trimmed }
            page = .invite
        case .invite:
            settings.hasCompletedOnboarding = true
            onFinish()
        }
    }

    private func back() {
        switch page {
        case .intro: break
        case .identity: page = .intro
        case .invite: page = .identity
        }
    }
}
