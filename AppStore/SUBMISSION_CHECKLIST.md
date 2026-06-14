# App Store Submission Checklist

Things that are **already done** in this repo, and things **you still have to do** to actually ship.

## Already Done in the Repo

- [x] App Sandbox enabled (`com.apple.security.app-sandbox: true`)
- [x] Hardened Runtime enabled (`ENABLE_HARDENED_RUNTIME: YES`)
- [x] Network client + server entitlements
- [x] Bonjour services declared (`_1on1._tcp`, `_1on1._udp`)
- [x] `NSLocalNetworkUsageDescription` set
- [x] `NSHumanReadableCopyright` set
- [x] `LSApplicationCategoryType` set (`public.app-category.social-networking`)
- [x] `ITSAppUsesNonExemptEncryption: false` (uses standard CryptoKit AES-GCM)
- [x] App icon PNGs generated and referenced from `AppIcon.appiconset/Contents.json`
- [x] `PrivacyInfo.xcprivacy` with Required Reasons + collected-data declarations
- [x] First-launch onboarding sheet (`WelcomeView` / `WelcomeWindowController`)
- [x] Sandboxed runtime smoke-tested locally
- [x] App Store metadata draft (`AppStore/metadata.md`)
- [x] Privacy policy draft (`AppStore/privacy-policy.md`)

## What You Have to Do Manually

### Account

- [ ] Enroll in the **Apple Developer Program** ($99/yr) at developer.apple.com. Personal dev accounts cannot ship to the Mac App Store.

### Certificates & profiles

- [ ] In Xcode → Settings → Accounts, sign in with the paid Apple ID.
- [ ] Generate a **Mac App Distribution** certificate.
- [ ] Generate a **Mac Installer Distribution** certificate.
- [ ] Register the bundle ID `com.markstudios.OneOnOne` at developer.apple.com if not already.
- [ ] Enable **iCloud + CloudKit** capability for the bundle ID.

### CloudKit production schema

- [ ] In CloudKit Dashboard → `iCloud.com.markstudios.OneOnOne` → Schema, ensure the public database has a `Message` record type with these queryable fields:
  - `roomHash` — String, queryable
  - `messageID` — String
  - `senderID` — String
  - `payload` — Bytes
  - `timestamp` — Date/Time, queryable + sortable
- [ ] **Deploy to Production.** Without this, the relay won't work for users outside your dev account.

### Re-enable iCloud entitlement in this repo

After your paid account is active, edit `project.yml` → `targets.OneOnOne.entitlements.properties` and add:

```yaml
com.apple.developer.icloud-services:
  - CloudKit
com.apple.developer.icloud-container-identifiers:
  - iCloud.com.markstudios.OneOnOne
```

Then `make generate && make build`. (This is currently commented out so local builds with the personal dev account succeed.)

### Hosting

- [ ] Host the privacy policy at `https://markstudios.com/1on1/privacy` (markdown source: `AppStore/privacy-policy.md`).
- [ ] Host a support page at `https://markstudios.com/1on1/support`.
- [ ] (Optional) Marketing page at `https://markstudios.com/1on1`.

### App Store Connect

- [ ] Create a new app at appstoreconnect.apple.com using the bundle ID and an SKU like `oneonone-1`.
- [ ] Paste in the metadata from `AppStore/metadata.md` (subtitle, description, keywords, promo text, what's new, support URL, privacy URL, marketing URL).
- [ ] Pick the age rating (likely 4+).
- [ ] Pick the price tier (Free recommended for v1).
- [ ] Upload **screenshots** (1280×800 minimum, ideally 2880×1800 for retina). Suggested set:
  1. Floating overlay catching your eye on a busy desktop.
  2. Compose popover showing "Share your code".
  3. Settings → Profile tab.
  4. Conversation window with a few messages and the typing indicator.
  5. Screenshot-share in action.
- [ ] (Optional) App preview video (15–30s).

### Build & Upload

- [ ] In Xcode: Product → Archive.
- [ ] Distribute App → App Store Connect → Upload.
- [ ] Wait for processing (5–30 min).
- [ ] In App Store Connect, attach the build to your version, add **App Review notes** from `AppStore/metadata.md`, and submit for review.

### After approval

- [ ] When approved, click "Release" in App Store Connect.
- [ ] Bump `CFBundleVersion` for any future build (must be strictly increasing).
- [ ] Use TestFlight for beta builds before each release.

## Likely Reviewer Concerns

1. **"How do we test this without a partner?"** — covered in `App Review Information notes` in `metadata.md`. Use two Macs on the same iCloud account.
2. **CloudKit relay rejection.** If reviewer can't get the relay to work, they may reject. Mitigation: ensure the schema is deployed to Production and that the welcome screen makes the local-network-only path obviously functional.
3. **Sound startles reviewer.** Consider whether to default `soundEnabled` to `false` — currently it's `true`.
4. **Screen Recording permission.** Reviewers sometimes flag this. Ensure the `NSScreenCapture` permission prompt has clear copy in the Cmd-Shift-2 failure alert (already implemented in `ScreenshotManager`).
