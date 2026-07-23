# Telegraphica ✦ Legacy Telegram for Intel Macs

<div align="center">
  <img src="readme-assets/app-icon.png" alt="Telegraphica app icon" width="120" />
  <p><b>An experimental, unofficial Telegram client for OS X 10.8 through macOS 10.13 on Intel Macs.</b></p>
  <p>
    <img src="https://img.shields.io/badge/version-v0.5.1-blue" alt="version v0.5.1" />
    <img src="https://img.shields.io/badge/macOS-10.8--10.13-black" alt="OS X 10.8 through macOS 10.13" />
    <img src="https://img.shields.io/badge/Objective--C-AppKit-lightgrey" alt="Objective-C AppKit" />
    <img src="https://img.shields.io/badge/Telegram-TDLib%20JSON-2CA5E0" alt="TDLib JSON" />
    <img src="https://img.shields.io/badge/status-open%20beta-brightgreen" alt="open beta status" />
    <img src="https://img.shields.io/badge/no-Electron-success" alt="no Electron" />
  </p>
  <p>
    📣 <a href="https://t.me/macos_telegraphica"><b>Follow development news and release announcements on Telegram</b></a>
  </p>
</div>

Telegraphica is a small native Cocoa/AppKit Telegram client for **OS X 10.8
through macOS 10.13** on Intel `x86_64`. It is intended for every Intel-based
Mac, including MacBook models, that can run one of those operating systems.
Newer Intel Macs and Apple Silicon Macs may also run the app, but those
configurations are unofficial and the author cannot guarantee current or future
compatibility.

It is not a Telegram clone, not an official Telegram app, and not a branded
Telegram distribution. It is an independent legacy-Mac experiment that talks to
Telegram through **TDLib's JSON API** and keeps the UI native, small, and
legacy-Mac-friendly.

> Telegraphica is not affiliated with Telegram. This repository does not include
> Telegram logos, official artwork, user credentials, TDLib databases, sessions,
> or account data.

---

## Compatibility

Telegraphica has two release lanes: a dedicated Mountain Lion build for 10.8
and the standard build for 10.9-10.13. Both are Intel-only.

| macOS version | Telegraphica support began | Architecture | Status |
| --- | --- | --- | --- |
| OS X 10.8 Mountain Lion | `v0.4.5-ml` | Intel `x86_64` | Supported through the separate `-ml` release |
| OS X 10.9 Mavericks | First public mainline release | Intel `x86_64` | Primary supported platform |
| OS X 10.10-10.13 | First public mainline release | Intel `x86_64` | Supported by the standard release |
| macOS 10.14-10.15 | No formal support milestone | Intel `x86_64` | Unofficial, best effort, not part of regular HITL testing |
| macOS 11-27 / Apple Silicon era | No formal support milestone | Intel `x86_64`; Rosetta 2 where available | Unofficial and untested; no native `arm64` build |
| macOS 28 and newer | No formal support milestone | No supported architecture | General-purpose Rosetta support for ordinary Intel apps is expected to be unavailable |

The exact operating systems available still depend on the Mac model. Apple says
that general-purpose Rosetta support for Intel apps remains available through
macOS 27 and ends after that release, with only a limited legacy-game exception.
See [Apple's Intel-app compatibility guidance](https://support.apple.com/102527).

Most development and hands-on testing happens on **OS X 10.9 Mavericks**. The
practical reason is that it provides the project's main legacy toolchain and
hardware baseline. The less serious reason is that the author likes
skeuomorphic systems and would like to make them great again.

---

## What Telegraphica Is For

Telegraphica exists for one very specific reason: keeping an old Mac useful for
real messaging again.

The current official Telegram Desktop client no longer supports these legacy
macOS releases. Telegram's web version remains an option, but keeping a modern
browser and a full web client open can place sustained CPU and memory pressure
on older hardware. That can contribute to heat, throttling, and visible system
slowdowns.

Telegraphica takes the opposite route: a native Objective-C/AppKit shell,
old-Xcode-safe code, TDLib underneath, and no embedded browser engine. The goal
is lower overhead so the system can "breathe easier" and leave more of its
limited resources available for other useful work.

In plain language, the goal is:

- 🧭 open Telegram on an Intel Mac running OS X 10.8 through macOS 10.13;
- 🔐 pass modern Telegram authorization through TDLib;
- 💬 read chats, topics, messages, media previews, and unread state;
- 📤 send text, photos, reactions, and voice messages;
- 🔔 integrate with Notification Center and the Dock;
- 🧰 keep the build reproducible for the old Mac lane.

---

## Current Open Beta: `v0.5.1`

This open beta is ready for broader legacy-Mac testing. Telegraphica is still
young software, but the everyday loop is now useful enough for real feedback:
sign in, read chats, send messages, handle media, manage pinned dialogs, play
voice messages, and keep the app updated from GitHub Releases.

### ✅ Working In This Beta

- 🔐 TDLib login flow: phone number, login code, and 2FA password.
- 🧾 Automatic TDLib app configuration bootstrap for public builds, with local
  developer override support.
- 💬 Chat list with unread badges, muted indicators, avatars, and selected chat
  state.
- 🧵 Supergroup topics / forum-style subchat selection.
- 📜 Message history with scroll-based older-message loading.
- ✍️ Typing indicators when TDLib reports active chat actions.
- 📨 Text sending with multiline input support.
- 🖼 Photo sending with preview and optional caption.
- 🎙 Voice-message recording, preview, sending, and playback.
- 🔊 Ogg/Opus voice-message playback through a bundled Mavericks-safe helper.
- 👍 Message reactions with local display and real Telegram sync.
- 🖼 Grouped photo display, image preview, zoom controls, and pinch-to-zoom.
- 🎞 Video playback in a resizable native window.
- 📎 Basic document display with filenames where TDLib exposes them.
- 🔔 Notification Center alerts, Dock unread badges, sound, and click-through to
  the source chat.
- 👤 Profile, settings, themes, language selector, diagnostics, and about panel.
- 🔄 Manual update checks and quiet update-available badges against GitHub
  Releases.
- 📌 Pinned dialogs stay at the top of the chat list and can be pinned or
  unpinned from the chat context menu.
- 🧩 Native sticker display with WEBP, TGS, and animated WEBM/VP9 sticker
  support on Mavericks.
- 🔍 Chat search/navigation with a native search field.
- 🧽 Storage usage view with cache cleanup.
- 🧹 Build/release hygiene scripts for the old-Mac workflow.

### ⚠️ Known Beta Gaps

- Some sticker packs may still expose edge-case animation/layout bugs; please
  report the sticker format and a screenshot if that happens.
- The DMG must be HFS+-formatted for Mavericks and is not notarized.
- A public drag-and-drop DMG is considered complete only when
  `Telegraphica.app` already bundles a Mavericks-compatible
  `Contents/Frameworks/libtdjson.dylib`.
- DMGs without bundled TDLib are development images, not out-of-the-box
  installers.
- Mainline release confidence comes from OS X 10.9.5 / Xcode 6.2 HITL testing;
  Mountain Lion uses its own Xcode 5.1.1-compatible release lane.
- The project is moving fast, so UI details and release packaging may change.

---

## Download & Run

Compiled beta builds live in:

➡️ **[GitHub Releases](https://github.com/MiChiRose/telegraphica/releases)**

### For Users

1. Open the latest release page.
2. Click **Assets** if the download list is collapsed.
3. Download the DMG for your system:
   - **OS X 10.8:** `Telegraphica-v0.5.1-macos10.8-x86_64.dmg` from the
     corresponding `-ml` release;
   - **OS X 10.9-10.13:** `Telegraphica-v0.5.1-macos10.9-x86_64.dmg`.
4. Open the downloaded DMG.
5. Drag **Telegraphica.app** into **Applications**.
6. Launch Telegraphica and sign in with your Telegram phone number.

If you are not sure which file to download, choose the file ending in
**`.dmg`**.

### For Developers / Troubleshooting

| Asset | Best For | Notes |
| --- | --- | --- |
| `Telegraphica-v0.5.1-macos10.8-x86_64.dmg` | OS X 10.8 installation | Use the separate `v0.5.1-ml` release for Mountain Lion. |
| `Telegraphica-v0.5.1-macos10.9-x86_64.dmg` | OS X 10.9-10.13 installation | Standard supported release. |
| `Telegraphica-v0.5.1-macos10.9-x86_64.app.zip` | Manual app bundle transfer | Use this only if the DMG is inconvenient. |
| `.sha256` files | Checksum verification | You do not need these files to install Telegraphica. |

### First Launch

Because Telegraphica is distributed directly and is not notarized yet, macOS may
warn on first launch.

1. Download the `.dmg` file from the release assets.
2. Open the DMG and drag **Telegraphica.app** into **Applications**.
3. If macOS blocks the app, right-click / Control-click the app and choose
   **Open**.
4. Sign in with your phone number, Telegram code, and 2FA password if needed.

---

## Legacy Build Guide

Telegraphica is intentionally built around a conservative Objective-C lane:

| Item | Target |
| --- | --- |
| OS | OS X 10.8 through macOS 10.13; 10.8 uses the separate Mountain Lion lane |
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
should be uploaded to GitHub for an out-of-the-box Mavericks beta.

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

Public release builds fetch the Telegraphica TDLib app configuration
automatically on first launch so people can sign in without manually entering
Telegram API fields. Do not add plaintext release credentials to app resources
or repository files.

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
- 🧹 **Clean release artifacts:** public builds exclude `.git`, `dist`, build
  outputs, TDLib source trees, credentials, and sessions.

---

## Roadmap

- Improve edge-case animated sticker playback and GIF handling.
- More complete document download and preview handling.
- Richer contact/profile views.
- More polished skeuomorphic theme variants.
- Safer automatic update flow for legacy Macs.
- Optional all-in-one installer once the redistributable Mavericks TDLib lane is
  finalized.

---

## Compatibility & Security

**Supported target:** OS X 10.8 through macOS 10.13 on Intel `x86_64`.

The mainline build targets 10.9-10.13. OS X 10.8 uses the separate
`mountain-lion/*` source and `-ml` release lane. Newer Intel and Apple Silicon
systems may work, including through Rosetta 2, but they are unofficial, are not
regular release gates, and have no native `arm64` binary. General-purpose
Rosetta support for ordinary Intel apps is available through macOS 27; continued
operation after that version is not expected or guaranteed.

**Security posture:**

- public builds fetch Telegraphica app-level Telegram API configuration on first launch;
- no bundled user credentials, phone numbers, login codes, or 2FA passwords;
- no committed sessions or TDLib databases;
- diagnostics are redacted where practical;
- local secrets belong in Application Support and Keychain, not in source;
- release archives are checked before publishing.

---

## Issues & Feedback

This is beta software. Bugs, UI notes, old-Mac build logs, and compatibility
reports are welcome:

- [GitHub Issues](../../issues)
- [GitHub Releases](../../releases)

---

<p align="center">
  Made for the stubbornly useful old Macs that still deserve good software.
</p>
