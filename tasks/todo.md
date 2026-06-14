# 1on1 Build Completion

## Checklist

- [x] Inspect repository structure, existing local changes, and build configuration.
- [x] Run baseline package/app build commands and capture concrete failures.
  - Initial `swift test` passed with 4 tests and exposed a `DatabaseManager.clearHistory()` warning.
- [x] Fix build blockers with minimal, idiomatic Swift changes.
  - Normalize received network messages as remote-owned.
  - Tag CloudKit records with a stable client id and skip this client's own relay records.
  - Clean Swift 6/AppKit and GRDB build warnings.
  - Move relay records out of private CloudKit storage so two iCloud accounts can share a room.
  - Allow compose sends through CloudKit/queueing when no local peer is connected.
  - Reactivate relay when the room code changes in Settings.
  - Persist relay dedup state to avoid replaying old messages after relaunch.
- [x] Re-run tests and app build until they pass.
- [x] Review the final diff for scope, user-owned changes, and avoidable complexity.

## Review

- `swift test` passes with 5 tests.
- `make build` succeeds and produces a signed Debug `OneOnOne.app`.
- Launch smoke test passed: the built app starts as a menu-bar process and quits cleanly.
- CloudKit relay code now uses encrypted public room records and checks CloudKit account availability before marking relay active. Enabling the actual iCloud entitlement on this machine failed because the active Apple account is a personal development team, which does not support iCloud capabilities; a paid Apple Developer team/container is required before CloudKit relay can work in a signed app.

## Continuation

- [x] Add a CloudKit database access probe before marking the relay active.
- [x] Document CloudKit signing/container requirements.
- [x] Re-run package tests, app build, and launch smoke test.

## Continuation Review

- Added a public CloudKit database probe so relay activation fails closed when signing/container access is unavailable.
- Documented CloudKit requirements in `README.md`, including paid Apple Developer team, entitlement/container setup, and required public indexes.
- Re-verified `swift test`, `make build`, and launch smoke test after the continuation changes.

## Screenshot Continuation

- [x] Add first-class screenshot message payloads.
- [x] Persist screenshot payload metadata in SQLite.
- [x] Render screenshot thumbnails in history and overlays.
- [x] Re-run package tests, app build, and launch smoke test.

## Screenshot Continuation Review

- `swift test` passes with 6 tests, including screenshot payload encode/decode coverage.
- `make build` succeeds and produces a signed Debug `OneOnOne.app`.
- Launch smoke test passed: the built executable starts and remains running before controlled shutdown.

## Product Completion Pass

- [x] Audit remaining advertised workflows for missing implementation or broken edge cases.
- [x] Fix the highest-impact gaps with minimal code changes.
- [x] Add focused tests where behavior is package-level and testable.
- [x] Re-run package tests, app build, launch smoke test, and final diff checks.

## Product Completion Review

- Added CloudKit query pagination so relay polling does not miss later pages in busy rooms.
- Cloud send failures now requeue durable user messages instead of dropping them, while transient typing/read-receipt messages are not queued stale.
- Reading in the history window now clears unread state and pending quiet-hours overlays before sending the read receipt.
- Typing/read receipts now use the router, so they work over relay when active.
- Quiet-hours pending overlays are persisted by message id across relaunch and cleared after delivery or after the user reads history.
- Screenshot capture now checks Screen Recording permission, shows a recovery alert on failure, and compresses screenshots under relay-friendly payload limits.
- Menu bar icons now use colored status tinting, and screenshot thumbnails use fit scaling instead of cropping.
- `swift test` passes with 8 tests.
- `make build` succeeds and produces a signed Debug `OneOnOne.app`.
- Launch smoke test passed and no `OneOnOne` process remains running.
- `git diff --check` passes.

## Durability + UX Pass

- [x] Persist `TransportRouter.pendingQueue` so offline-queued messages survive relaunch.
- [x] Add a "Resend" action for failed/queued messages in the history view.
- [x] Add a "Generate" room code button (random, share-friendly) in Settings.
- [x] Re-run package tests, app build, launch smoke test.

## Durability + UX Review

- `TransportRouter` now persists its pending queue to `UserDefaults` on every queue/flush/retry, and rehydrates on init. Offline-queued messages no longer vanish on quit.
- Conversation rows show a tappable "Queued · Retry" / "Failed · Retry" indicator and a "Resend" context menu item; both route through a new `TransportRouter.retry(_:)` that dedups against the pending queue.
- Settings → Connection has a "Generate" button (12-char unambiguous alphabet, dash-separated) and a copy button next to the room code.
- `swift test` passes with 10 tests, including new coverage for queue persistence across instances and retry-deduplication.
- `make build` succeeds and produces a signed Debug `OneOnOne.app`; launch smoke test starts the menu-bar process and shuts down cleanly.
- `git diff --check` passes.

## Identity + Settings UX Pass

- [x] Add `MessageType.presence` and broadcast my display name on peer/relay connect.
- [x] Auto-populate partner name from incoming presence messages; persist across relaunch.
- [x] Add a Profile concept: `myDisplayName` + auto-generated `myHandle`, stored in `SettingsManager`.
- [x] Add a Profile tab to Settings (display name, handle with copy/regenerate); remove the manual "Partner Name" field from General.
- [x] Reorder Settings tabs: Profile, Connection, Notifications, General. Rename "Room Code" → "Partner's Code".
- [x] Add a gear button in the compose popover header that opens Settings.
- [x] Replace "Offline/Connecting…" copy with "Connected to <name>" / "Waiting for partner…".
- [x] Empty compose state: "Share your code" with a one-tap copy when no partner is configured yet.
- [x] Re-run package tests, app build, launch smoke test.

## Identity + Settings UX Review

- New `MessageType.presence` carries the sender's display name. AppDelegate broadcasts presence on peer connect, on cloud relay activation, and whenever the user edits their own display name.
- Partner name auto-populates from incoming presence and is persisted to `settings.lastPartnerName` so the UI shows the right name immediately on relaunch. The manual "Partner Name" setting is gone.
- `SettingsManager` now owns a Profile: `myDisplayName` (defaults to the system computer name) and `myHandle` (auto-generated unambiguous 12-char code, persistent across launches, regeneratable). Outgoing messages now use `myDisplayName` instead of `Host.current().localizedName`.
- Settings is rebuilt as four tabs: **Profile** (name + handle with copy/regenerate), **Connection** ("Partner's Code" with copy), **Notifications**, **General** (overlay size + launch at login).
- Compose popover header has a new gear button that opens Settings. When no partner code is set yet, the popover replaces the input with a "Share your code" card showing the user's handle, a Copy button, and a shortcut to Connection settings.
- Connection copy now reads "Connected to Sarah" / "Connecting to Sarah…" / "Waiting for partner…" / "Share your code to connect" depending on actual state.
- `swift test` passes with 10 tests; `make build` succeeds and the launch smoke test starts and exits cleanly. New Release DMG at `build/1on1.dmg` (4.2 MB).

## App Store Readiness Pass

Things I implemented (code/config) — Mark still has to: enroll in the paid Apple Developer Program, generate Distribution certs, deploy CloudKit production schema, host privacy-policy/support URLs, and create the App Store Connect listing. See `AppStore/SUBMISSION_CHECKLIST.md`.

- [x] Populate `AppIcon.appiconset` with actual PNGs at all required sizes (extract from existing `AppIcon.icns`).
- [x] Enable App Sandbox + Hardened Runtime in entitlements.
- [x] Add CloudKit container entitlement, gated behind a comment so personal-cert builds still succeed.
- [x] Add Info.plist keys: `LSApplicationCategoryType`, `NSHumanReadableCopyright`, `ITSAppUsesNonExemptEncryption`, `LSMinimumSystemVersion`, etc.
- [x] Create `PrivacyInfo.xcprivacy` with Required Reasons + collected data declarations.
- [x] Audit and verify sandbox-compatible code paths (DB now writes to sandboxed Application Support; all networking, hotkeys, screenshots, login items work).
- [x] First-launch onboarding sheet: explains the app, lets user pick a display name, shows the user's code with a Copy button.
- [x] Draft App Store metadata: subtitle, description, keywords, promotional text, "What's New", review notes.
- [x] Draft a stub privacy policy (Mark hosts it).
- [x] Re-run package tests, app build (Debug + Release), launch smoke test, sandboxed smoke test.

## App Store Readiness Review

- **Sandbox + Hardened Runtime are on.** App launches cleanly under sandbox; SQLite database now writes to `~/Library/Containers/com.markstudios.OneOnOne/Data/Library/Application Support/OneOnOne/`. Hotkeys (Carbon `RegisterEventHotKey` via the HotKey package), MultipeerConnectivity (with declared Bonjour services + `NSLocalNetworkUsageDescription`), ScreenCaptureKit, and SMAppService launch-at-login all work under sandbox.
- **iCloud entitlement is parked behind a documented block in `project.yml`.** Personal Apple development accounts can't generate provisioning profiles that include iCloud capabilities, so leaving it on broke `make build` — the YAML now has commented instructions for re-enabling it once Mark has a paid account.
- **App icon assets are real now.** Extracted ten properly-sized PNGs (16/32/128/256/512 at @1x and @2x) from the existing `AppIcon.icns` and wired them into `AppIcon.appiconset/Contents.json`.
- **Info.plist** has the App Store-required keys: `LSApplicationCategoryType`, `LSMinimumSystemVersion`, `CFBundleShortVersionString`, `CFBundleVersion`, `NSHumanReadableCopyright`, `ITSAppUsesNonExemptEncryption`.
- **`PrivacyInfo.xcprivacy`** declares: no tracking, "Other User Content" + "Photos or Videos" collected for app functionality, and Required Reasons for `UserDefaults` (CA92.1), `FileTimestamp` (C617.1), `DiskSpace` (E174.1), `SystemBootTime` (35F9.1).
- **Welcome screen** runs on first launch only — three-page flow (intro → display name → share-your-code with Copy). Driven by `settingsManager.hasCompletedOnboarding`.
- **App Store assets** drafted at `AppStore/metadata.md` (subtitle, description, keywords, promo text, review notes), `AppStore/privacy-policy.md`, and `AppStore/SUBMISSION_CHECKLIST.md` (everything Mark still has to do manually).
- **Tests pass** (10 tests). **Debug and Release** both build clean. **Sandboxed smoke test** confirmed by inspecting the new container at `~/Library/Containers/com.markstudios.OneOnOne/`. New Release DMG at `build/1on1.dmg` (4.6 MB, sandboxed, hardened runtime).

## App Store Polish Pass

- [x] Add an in-app About window (version, build, copyright, links to Privacy / Support / Send Feedback).
- [x] Add "About 1on1" to the right-click menu so reviewers and users can find legal/support links.
- [x] Confirmation dialog when regenerating the user's handle (it's destructive — partner has the old code saved).
- [x] Re-run package tests, app build, smoke test, rebuild DMG.

## App Store Polish Review

- New `AboutView` + `AboutWindowController` show the app icon, version (`1.0.0 (1)`), copyright, and three buttons that open `https://markstudios.com/1on1/privacy`, `https://markstudios.com/1on1/support`, and a `mailto:hello@markstudios.com` with a pre-filled subject including the version. Reads version/build/copyright from `Bundle.main.infoDictionary`.
- Status bar right-click menu now shows: Message History · Settings… · **About 1on1** · status line · Quit. Wired through `StatusBarController.onShowAbout` from `AppDelegate`.
- Settings → Profile → regenerate-handle button now triggers a `confirmationDialog` warning that the partner has the current code saved and would need to be re-shared. Cancelable.
- Tests still 10/10. Debug + Release builds clean. New DMG at `build/1on1.dmg` (6.4 MB, includes proper icon assets now).

## Apple-Audit Fix Pass

Items 1–8 from the Apple audit. Privacy/support/marketing URLs (item #9) are still on Mark to host.

- [x] Add `CFBundleDisplayName=1on1`, `CFBundleName=1on1`, `CFBundleSpokenName=one on one` so the app appears as "1on1" everywhere.
- [x] Drop `NSPrivacyCollectedDataTypePhotosorVideos` from `PrivacyInfo.xcprivacy` — keep only `OtherUserContent`.
- [x] Build a real `NSApp.mainMenu` (App / Edit / Window / Help) so Cmd-Q, Cmd-W, and standard text-editing shortcuts work in focused windows.
- [x] Default `soundEnabled` to `false` for new users.
- [x] Set a dynamic tooltip on the menu bar icon ("1on1 — Connected to Sarah · 2 unread").
- [x] Warn in Settings → Connection if the user enters their own handle as the partner code; AppDelegate also refuses to activate a relay against the user's own room.
- [x] CloudKit polling now backs off from 2s → 30s after 30 consecutive empty polls; resets on any new message, on user-sent messages, and when the popover opens.
- [x] Delete unused `OneOnOne/AppIcon.icns` — asset catalog is the source of truth.
- [x] Re-run package tests, app build, smoke test, rebuild DMG.

## Apple-Audit Fix Review

- Verified `CFBundleName`, `CFBundleDisplayName`, `CFBundleSpokenName` in the built bundle all read `1on1` / `one on one` via `PlistBuddy`. Dock, Spotlight, Force Quit dialog will all show "1on1" now.
- `PrivacyInfo.xcprivacy` now only declares "Other User Content" — accurate to what the app actually collects (relay messages and screenshots).
- New `setupMainMenu()` in `AppDelegate.applicationDidFinishLaunching` constructs a proper main menu with the App, Edit, Window, and Help items. `NSApp.helpMenu` is registered so macOS can decorate it correctly. Cmd-Q now quits, Cmd-W closes windows, Edit shortcuts work.
- `SettingsManager.soundEnabled` initializes to `false` for new users; existing users keep their stored preference.
- `StatusBarController.updateIcon` now sets `button.toolTip` from a `currentTooltip` getter that reflects connection state, partner name, and unread count.
- Settings → Connection shows an inline warning when `roomCode == myHandle`; `AppDelegate.configureCloudRelay` early-returns if so.
- `CloudRelayManager` tracks `consecutiveEmptyPolls` and uses 2s while active, 30s after going idle. New `bumpToActivePolling()` is called from message sends and popover opens via a `StatusBarController.onUserActivity` callback.
- Tests 10/10. Debug + Release builds succeed. Sandboxed smoke test still launches and exits cleanly. New DMG at `build/1on1.dmg` (4.6 MB).
