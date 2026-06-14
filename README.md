<div align="center">

# 💬 1on1

**Direct messages that demand attention — floating overlays for two.**

[![Swift](https://img.shields.io/badge/Swift-6.0-F05138?style=for-the-badge&logo=swift&logoColor=white)](https://swift.org)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-Framework-007AFF?style=for-the-badge&logo=apple&logoColor=white)](https://developer.apple.com/swiftui)
[![macOS](https://img.shields.io/badge/macOS-14%2B-000000?style=for-the-badge&logo=apple&logoColor=white)](https://www.apple.com/macos)
[![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)](LICENSE)

[Features](#features) · [Getting Started](#getting-started) · [Tech Stack](#tech-stack)

</div>

---

## Features

- **Floating Overlays** — Messages appear as large, unmissable panels centered on your screen with blur-material backgrounds and spring animations
- **Menu Bar App** — Lives in your status bar with connection status icons (gray/green/blue/orange) and a compose popover
- **Local Peer-to-Peer** — Zero-config discovery and messaging over MultipeerConnectivity with automatic reconnect and exponential backoff
- **CloudKit Relay** — Share a room code to message across networks with HKDF-derived end-to-end encryption
- **Smart Routing** — TransportRouter prefers local MC when available, falls back to CloudKit automatically, deduplicates by message ID
- **Message History** — GRDB-backed SQLite persistence with iMessage-style conversation bubbles and live UI updates via ValueObservation
- **Typing Indicators** — Real-time typing state with 3-second debounce, animated status bar icon
- **Encrypted Transport** — Local messaging requires MultipeerConnectivity encryption; CloudKit relay payloads use CryptoKit AES-GCM with keys derived from the shared room code
- **Screenshot Sharing** — Capture and send screenshots with Cmd+Shift+2 via ScreenCaptureKit
- **Quiet Hours** — Queue incoming messages during set hours, deliver them all when quiet hours end
- **Global Hotkeys** — Cmd+Shift+1 to compose, Cmd+Shift+2 to screenshot
- **Settings** — Partner name, overlay size (S/M/L), sound toggle, quiet hours, launch at login, room code

## Getting Started

### Prerequisites

- macOS 14.0+
- Xcode 16.0+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

### Installation

```bash
git clone https://github.com/markksantos/1on1.git
cd 1on1
make generate
make build
```

### Permissions

On first launch, macOS will prompt for:

- **Local Network** — Required for peer-to-peer discovery and messaging
- **Screen Recording** — Required for screenshot sharing (Cmd+Shift+2)

### CloudKit Relay Setup

Local peer-to-peer messaging builds and runs with a standard Mac development profile. The internet relay requires a paid Apple Developer team with iCloud/CloudKit enabled for `com.markstudios.OneOnOne`.

To ship relay support:

1. Enable iCloud and CloudKit for the app identifier in Apple Developer.
2. Add the app's CloudKit container to `OneOnOne/OneOnOne.entitlements` and `project.yml`.
3. Create the public `Message` record type in CloudKit Dashboard with queryable `roomHash` and `timestamp` fields.

If the app is signed without CloudKit capability, the relay stays inactive and local peer-to-peer messaging still works.

## Tech Stack

| Component | Technology |
|---|---|
| Language | Swift 6.0 |
| UI Framework | SwiftUI + AppKit |
| Networking | MultipeerConnectivity |
| Cloud Relay | CloudKit |
| Database | GRDB.swift (SQLite) |
| Encryption | MultipeerConnectivity encryption + CryptoKit AES-GCM for relay payloads |
| Hotkeys | HotKey (soffes/HotKey) |
| Screenshots | ScreenCaptureKit |
| Build System | XcodeGen + SPM |

## Project Structure

```
1on1/
├── project.yml
├── Makefile
├── OneOnOne/
│   ├── AppDelegate.swift
│   ├── StatusBarController.swift
│   ├── MessageOverlayPanel.swift
│   ├── OverlayStackManager.swift
│   ├── ConversationWindowController.swift
│   ├── SettingsWindowController.swift
│   ├── ScreenshotManager.swift
│   ├── OneOnOne.entitlements
│   ├── Info.plist
│   └── Assets.xcassets/
├── Packages/OneOnOneKit/
│   ├── Package.swift
│   ├── Sources/
│   │   ├── OneOnOneEngine/
│   │   │   ├── Models/
│   │   │   │   ├── Message.swift
│   │   │   │   └── Peer.swift
│   │   │   ├── Networking/
│   │   │   │   ├── PeerManager.swift
│   │   │   │   ├── CloudRelayManager.swift
│   │   │   │   └── TransportRouter.swift
│   │   │   ├── Storage/
│   │   │   │   ├── DatabaseManager.swift
│   │   │   │   ├── KeychainManager.swift
│   │   │   │   └── SettingsManager.swift
│   │   │   └── Crypto/
│   │   │       └── MessageEncryptor.swift
│   │   └── OneOnOneUI/
│   │       ├── InputPopover/
│   │       │   └── ComposeView.swift
│   │       ├── Overlay/
│   │       │   └── MessageOverlayView.swift
│   │       ├── History/
│   │       │   └── ConversationView.swift
│   │       └── Settings/
│   │           └── SettingsView.swift
│   └── Tests/
│       └── OneOnOneEngineTests/
│           └── MessageTests.swift
```

## License

MIT License &copy; 2026 Mark Santos

---

<div align="center">

Built with ❤️ by [NoSleepLab](https://nosleeplab.com)

</div>
