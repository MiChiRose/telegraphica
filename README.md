# Telegraphica ✦ Legacy Telegram for Mavericks

<div align="center">
  <img src="readme-assets/app-icon.png" alt="Telegraphica app icon" width="120" />
  <p><b>An experimental, unofficial Telegram client for OS X 10.9.5 Mavericks.</b></p>
  <p>
    <img src="https://img.shields.io/badge/version-v0.3.0--alpha.2-blue" alt="version v0.3.0-alpha.2" />
    <img src="https://img.shields.io/badge/macOS-10.9.5%20Mavericks-black" alt="OS X 10.9.5 Mavericks" />
    <img src="https://img.shields.io/badge/Objective--C-AppKit-lightgrey" alt="Objective-C AppKit" />
    <img src="https://img.shields.io/badge/Telegram-TDLib%20JSON-2CA5E0" alt="TDLib JSON" />
    <img src="https://img.shields.io/badge/status-alpha-orange" alt="alpha status" />
    <img src="https://img.shields.io/badge/no-Electron-success" alt="no Electron" />
  </p>
</div>

Telegraphica is a small native Cocoa/AppKit Telegram client built for people
who still use Intel Macs on **OS X 10.9.5 Mavericks** and do not want to give up
working hardware just because modern clients moved on.

It is not a Telegram clone, not an official Telegram app, and not a branded
Telegram distribution. It is an independent legacy-Mac experiment that talks to
Telegram through **TDLib's JSON API** and keeps the UI native, small, and
Mavericks-friendly.

> Telegraphica is not affiliated with Telegram. This repository does not include
> Telegram logos, official artwork, user credentials, TDLib databases, sessions,
> or account data.

---

## What Telegraphica Is For

Telegraphica exists for one very specific reason: keeping an old Mac useful for
real messaging again.

Modern Telegram Desktop builds no longer target OS X Mavericks, and web clients
can be heavy or brittle on vintage browsers. Telegraphica takes the opposite
route: a native Objective-C/AppKit shell, old-Xcode-safe code, TDLib underneath,
and a UI shaped around the constraints of a 2013-era Mac.

In plain language, the goal is:

- 🧭 open Telegram on OS X 10.9.5;
- 🔐 pass modern Telegram authorization through TDLib;
- 💬 read chats, topics, messages, media previews, and unread state;
- 📤 send text, photos, reactions, and voice messages;
- 🔔 integrate with Notification Center and the Dock;
- 🧰 keep the build reproducible for the old Mac lane.

---

## Current Alpha: `v0.3.0-alpha.2`

This alpha is the first public build that is useful enough for live feedback.
It is still rough, but the core loop works.

### ✅ Working In This Alpha

- 🔐 TDLib login flow: phone number, login code, and 2FA password.
- 💬 Chat list with unread badges, muted indicators, avatars, and selected chat
  state.
- 🧵 Supergroup topics / forum-style subchat selection.
- 📜 Message history with scroll-based older-message loading.
- ✍️ Typing indicators when TDLib reports active chat actions.
- 📨 Text sending with multiline input support.
- 🖼 Photo sending with preview and optional caption.
- 🎙 Voice-message recording, preview, sending, and playback.
- 👍 Message reactions with local display and real Telegram sync.
- 🖼 Grouped photo display, image preview, zoom controls, and pinch-to-zoom.
- 🎞 Video playback in a resizable native window.
- 📎 Basic document display with filenames where TDLib exposes them.
- 🔔 Notification Center alerts, Dock unread badges, sound, and click-through to
  the source chat.
- 👤 Profile, settings, themes, language selector, diagnostics, and about panel.
- 🧹 Build/release hygiene scripts for the old-Mac workflow.

### ⚠️ Known Alpha Gaps

- Sticker and GIF rendering is still incomplete and can fall back to emoji.
- The DMG must be HFS+-formatted for Mavericks and is not notarized.
- A public drag-and-drop DMG is considered complete only when
  `Telegraphica.app` already bundles a Mavericks-compatible
  `Contents/Frameworks/libtdjson.dylib`.
- DMGs without bundled TDLib are development images, not out-of-the-box
  installers.
- Release confidence still comes from OS X 10.9.5 / Xcode 6.2 HITL testing.
- The project is moving fast, so UI details and release packaging may change.

---

## Download & Run

Compiled prereleases live in:

➡️ **[GitHub Releases](https://github.com/MiChiRose/telegraphica/releases)**

Latest alpha assets:

| Asset | Best For | Notes |
| --- | --- | --- |
| `Telegraphica-v0.3.0-alpha.2-installer.dmg` | Installer-format test | HFS+ DMG for Mavericks. This alpha image fixes mounting, but it is not a complete out-of-box Telegram installer unless the app bundle includes `Contents/Frameworks/libtdjson.dylib`. |
| `Telegraphica-develop-...-hfs-dmg-hotfix.zip` | Old-Mac source/build handoff | Use this when building with a local Mavericks TDLib setup. |

### First Launch

Because Telegraphica is distributed directly and is not notarized yet, macOS may
warn on first launch.

1. Download a release asset.
2. Open the DMG or unpack the source handoff.
3. If Gatekeeper blocks the app, right-click / Control-click the app and choose
   **Open**.
4. Configure your local TDLib credentials outside the repository.
5. Sign in with your phone number, Telegram code, and 2FA password if needed.

---

## Legacy Build Guide

Telegraphica is intentionally built around a conservative Objective-C lane:

| Item | Target |
| --- | --- |
| OS | OS X 10.9.5 Mavericks |
| CPU | Intel `x86_64` |
| UI | Cocoa / AppKit |
| Language | Objective-C, non-ARC |
| Telegram core | TDLib JSON API (`tdjson`) |
| Preferred legacy toolchain | Xcode 6.2 |

Build the app:

```sh
./build_legacy.sh
```

Bundle a local TDLib JSON library into the app:

```sh
TELEGRAPHICA_TDJSON_PATH=/path/to/libtdjson.dylib ./build_legacy.sh
```

Create a DMG from the built app:

```sh
./scripts/package_release_installer.sh
```

The installer packager refuses to create a public DMG unless the built app
contains `Telegraphica.app/Contents/Frameworks/libtdjson.dylib`. A
development-only TDLib-less image can be forced with
`TELEGRAPHICA_ALLOW_TDLIBLESS_INSTALLER=1`, but that image should not be
published as an end-user installer.

On the legacy Mac, build the complete release artifacts in one pass:

```sh
./scripts/package_legacy_release_artifacts.sh --tdjson /path/to/libtdjson.dylib
```

That command rebuilds Telegraphica, bundles TDLib, creates an HFS+ DMG, creates
an app zip, and writes SHA256 files into `dist/`. These are the artifacts that
should be uploaded to GitHub for an out-of-the-box Mavericks alpha.

The build script targets `MACOSX_DEPLOYMENT_TARGET=10.9`, builds `x86_64`,
stamps `LSMinimumSystemVersion`, checks the resulting binary with `file`,
`lipo`, and `otool`, then writes release artifacts into `dist/`.

---

## TDLib

Telegraphica talks to Telegram through TDLib's C JSON API. The current practical
legacy target is **TDLib v1.8.0**.

Useful scripts:

```sh
./scripts/build_tdlib_legacy.sh --archive /path/to/td-v1.8.0.tar.gz --openssl-root /opt/local
./scripts/check_tdjson_legacy.sh /path/to/libtdjson.dylib
```

The app can load TDLib from:

- `Telegraphica.app/Contents/Frameworks/libtdjson.dylib`
- a path bundled by `TELEGRAPHICA_TDJSON_PATH`
- `/usr/local/lib/libtdjson.dylib`
- `/opt/homebrew/lib/libtdjson.dylib`
- `libtdjson.dylib` next to the current process

More detail:

- [`docs/mavericks-transfer.md`](docs/mavericks-transfer.md)
- [`docs/feasibility.md`](docs/feasibility.md)
- [`docs/security.md`](docs/security.md)

---

## Local Credentials

Telegram API credentials are read locally from:

```text
~/Library/Application Support/Telegraphica/tdlib-config.plist
```

Start from:

```text
docs/local-tdlib-config.example.plist
```

Copy that example outside the repository, edit the copy with values from
`my.telegram.org`, and keep the real file local to your Mac.

Never commit, upload, paste, or screenshot:

- `api_id` / `api_hash`
- phone numbers, login codes, or 2FA passwords
- TDLib databases or session files
- Keychain-backed encryption keys
- raw TDLib authorization responses
- private chat/message screenshots unless you intentionally want to share them

---

## Project Layout

```text
Telegraphica.xcodeproj/        Xcode project kept Xcode 6.x-compatible
Sources/                       Objective-C/AppKit source
Sources/Core/                  TDLib boundary and chat/message models
Sources/Services/              Logger and Keychain helpers
Sources/UI/                    Legacy AppKit chat shell
Sources/Resources/             App icons, localizations, bundled resources
readme-assets/                 README artwork
docs/                          Feasibility, security, Mavericks, release notes
scripts/                       Build, TDLib, validation, release helpers
build_legacy.sh                Main Mavericks/x86_64 build lane
PRODUCT.md                     Product and design direction
```

---

## Engineering Notes

- 🧱 **Native first:** no Electron, no web wrapper, no SwiftUI requirement.
- 🕰 **Old-Xcode-safe:** avoids modern AppKit APIs that would break Xcode 6.2.
- 🔌 **Dynamic TDLib boundary:** the app can launch without vendoring TDLib.
- 🔐 **Local data discipline:** credentials and sessions stay outside git.
- 🧪 **HITL-driven:** Mavericks/Xcode 6.2 testing remains the source of truth.
- 🧹 **Clean release artifacts:** source handoff archives are built from tracked
  files and exclude `.git`, `dist`, build outputs, TDLib trees, credentials, and
  sessions.

---

## Roadmap

- Better sticker and GIF rendering.
- More complete document download and preview handling.
- Richer contact/profile views.
- More polished skeuomorphic theme variants.
- Safer automatic update flow for legacy Macs.
- Optional all-in-one installer once the redistributable Mavericks TDLib lane is
  finalized.

---

## Compatibility & Security

**Supported target:** OS X 10.9.5 Mavericks on Intel `x86_64`.

Modern macOS can be used for editing and smoke checks, but the real target is
the old Mac lane.

**Security posture:**

- no bundled Telegram API credentials;
- no committed sessions or TDLib databases;
- diagnostics are redacted where practical;
- local secrets belong in Application Support and Keychain, not in source;
- release archives are checked before publishing.

---

## Issues & Feedback

This is alpha software. Bugs, UI notes, old-Mac build logs, and compatibility
reports are welcome:

- [GitHub Issues](../../issues)
- [GitHub Releases](../../releases)

---

<p align="center">
  Made for the stubbornly useful old Macs that still deserve good software.
</p>
