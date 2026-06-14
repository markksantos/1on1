# 1on1 Privacy Policy

_Last updated: May 6, 2026_

1on1 is built by Mark Studios LLC ("we", "our") for one purpose: letting two people send each other direct messages with as little data collection as humanly possible. This policy explains what 1on1 does and does not collect, store, or share.

## TL;DR

- We do not have a server. We never see your messages.
- Messages between you and your partner travel directly device-to-device on your local network when possible, and through your own iCloud (CloudKit) when not.
- All relayed messages are end-to-end encrypted before they leave your Mac.
- We do not run analytics, fingerprinting, ad tracking, or third-party trackers.

## Information 1on1 Stores Locally

The following data is stored only on your Mac, in the app's sandboxed Application Support folder:

- **Your messages.** Text and screenshots, persisted to a SQLite database for your message history.
- **Your settings.** Display name, your unique code, your partner's last known display name, partner's code, overlay size, sound preferences, quiet-hours range, launch-at-login choice, and a draft of any unsent message.

You can clear this data at any time using the **Clear History** action in the conversation window.

## Information Sent Through CloudKit

When you and your partner aren't on the same Wi-Fi network, 1on1 sends messages through CloudKit's public database in the app's container. Before sending:

- A symmetric key is derived from your partner's code using HKDF-SHA256.
- Each message is encrypted with AES-GCM using that key.
- Only the encrypted payload, a hash of the room code, the sender's anonymous client ID, and a timestamp are sent.

Apple's CloudKit servers receive only the encrypted payload. We have no access to your CloudKit data — only you and your partner do.

## Information We Collect

**None.** We do not collect, transmit, or store any data on our own servers. We have no servers.

## Permissions 1on1 Requests

- **Local Network.** Required to discover your partner's Mac on the same Wi-Fi.
- **Screen Recording.** Required only when you take a screenshot via Cmd-Shift-2.

You can revoke either permission at any time in System Settings → Privacy & Security.

## Children's Privacy

1on1 is not directed at children under 13. We do not knowingly collect any information from anyone.

## Changes to This Policy

If we change this policy we'll update the "Last updated" date above and bump the app version.

## Contact

Questions? Email hello@markstudios.com.
