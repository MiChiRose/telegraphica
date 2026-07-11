# Telegraphica

> A small, unofficial Telegram client for legacy Macs.

Telegraphica is an experimental Cocoa/AppKit Telegram client for **OS X 10.9.5
Mavericks** on Intel `x86_64`. It is built for people who want to keep older Mac
hardware useful without upgrading the operating system.

Current version: **v0.3.0-alpha.1**

> Telegraphica is not affiliated with Telegram. It does not include Telegram
> branding, logos, or official assets.

## ✨ What Works In This Alpha

- 🧭 Native AppKit chat shell with classic Mac-friendly skeuomorphic styling.
- 🔐 TDLib authorization flow: phone number, login code, and 2FA password.
- 💬 Chat list, unread badges, muted-chat indicators, folders/topics, and
  supergroup topic selection.
- 🧵 Message history with older-message loading while scrolling.
- ✍️ Typing indicators such as `Vasya is typing...` when TDLib reports chat
  actions.
- 📤 Sending text, photos with captions, reactions, and voice messages.
- 🖼 Photo grouping, image preview with zoom, video playback window, and document
  filename previews.
- 🔔 macOS Notification Center integration, Dock badges, notification sounds,
  and notification click-through to the source chat.
- 👤 Profile, settings, theme selector, language selector, logs, and about panel.
- 🧰 Mavericks-oriented build scripts, static compatibility checks, TDLib build
  helpers, and a release DMG packager.

## 🧪 Status

This is an **alpha** release. Telegraphica is already useful for live testing,
but it is still a developer-facing client with known gaps:

- TDLib is loaded dynamically through `libtdjson.dylib`.
- The repository does not vendor Telegram credentials, sessions, TDLib databases,
  or built TDLib binaries.
- Sticker/GIF support is still partial and may fall back to emoji previews.
- Installer builds are not notarized and are intended for legacy/local testing.
- Final confidence still comes from OS X 10.9.5 / Xcode 6.2 HITL testing.

## 🖥 Target Platform

| Item | Target |
| --- | --- |
| OS | OS X 10.9.5 Mavericks |
| CPU | Intel `x86_64` |
| UI | Cocoa / AppKit |
| Language | Objective-C, non-ARC |
| Telegram core | TDLib JSON API (`tdjson`) |
| Preferred legacy toolchain | Xcode 6.2 |

Modern Xcode can be used for editing and early smoke checks, but the legacy lane
is the compatibility target.

## 📦 Install From A Release

Download the latest GitHub Release assets:

- `Telegraphica-v0.3.0-alpha.1-installer.dmg` — drag-and-drop app installer.
- `Telegraphica-develop-<sha>-alpha-release.zip` — source handoff archive for
  building on the old Mac with your local TDLib setup.

If the app opens but reports that TDLib is unavailable, build or provide a
Mavericks-compatible `libtdjson.dylib`, then rebuild with:

```sh
TELEGRAPHICA_TDJSON_PATH=/path/to/libtdjson.dylib ./build_legacy.sh
```

The app can load TDLib from:

- `Telegraphica.app/Contents/Frameworks/libtdjson.dylib`
- the path passed through `TELEGRAPHICA_TDJSON_PATH` during packaging
- `/usr/local/lib/libtdjson.dylib`
- `/opt/homebrew/lib/libtdjson.dylib`
- `libtdjson.dylib` next to the current process

## 🛠 Build

Clone the repository and run:

```sh
./build_legacy.sh
```

The script:

- prefers `/Applications/Xcode_6.2.app/Contents/Developer` when available;
- targets `MACOSX_DEPLOYMENT_TARGET=10.9`;
- builds `x86_64`;
- stamps `LSMinimumSystemVersion`;
- checks the produced binary with `file`, `lipo`, and `otool`;
- creates a versioned app zip under `dist/`.

To bundle TDLib into the app:

```sh
TELEGRAPHICA_TDJSON_PATH=/path/to/libtdjson.dylib ./build_legacy.sh
```

To create a DMG installer from the built app:

```sh
./scripts/package_release_installer.sh
```

## 🧱 TDLib

Telegraphica uses TDLib through the C JSON API. The current practical target is
TDLib **v1.8.0** built for Mavericks.

Useful scripts:

```sh
./scripts/build_tdlib_legacy.sh --archive /path/to/td-v1.8.0.tar.gz --openssl-root /opt/local
./scripts/check_tdjson_legacy.sh /path/to/libtdjson.dylib
```

See:

- `docs/mavericks-transfer.md`
- `docs/feasibility.md`
- `docs/local-tdlib-config.example.plist`

## 🔑 Local Credentials

Telegram API credentials are read locally from:

```text
~/Library/Application Support/Telegraphica/tdlib-config.plist
```

Start from `docs/local-tdlib-config.example.plist`, copy it outside the
repository, and edit the copy with credentials from `my.telegram.org`.

Never commit or upload:

- `api_id` / `api_hash`
- phone numbers, login codes, or 2FA passwords
- TDLib databases or session files
- Keychain-backed encryption keys
- raw TDLib authorization responses

## 🗂 Repository Layout

```text
Telegraphica.xcodeproj/        Xcode project kept Xcode 6.x-compatible
Sources/                       Objective-C/AppKit source
Sources/Core/                  TDLib boundary and chat/message models
Sources/Services/              Logger and Keychain helpers
Sources/UI/                    Legacy AppKit chat shell
docs/                          Feasibility, security, and Mavericks notes
scripts/                       Build, TDLib, validation, and release helpers
build_legacy.sh                Main Mavericks/x86_64 build lane
PRODUCT.md                     Product/design direction
```

## 🧹 Release Hygiene

Before publishing a release, run:

```sh
python3 scripts/check_legacy_compat.py
bash -n build_legacy.sh
bash -n scripts/build_tdlib_legacy.sh
bash -n scripts/check_tdjson_legacy.sh
bash -n scripts/package_release_installer.sh
```

Then build, package, and verify that release archives do not include `.git`,
`dist`, build outputs, credentials, sessions, or extracted TDLib trees.

## 🗺 Roadmap

- Better sticker and GIF rendering.
- More complete document download handling.
- Richer profile/contact views.
- Safer update flow for legacy Macs.
- Optional all-in-one installer once a redistributable Mavericks TDLib lane is
  finalized.

## ⚖️ License

License information is not finalized yet. Until a license is added, treat the
repository as source-available for review and testing, not as freely relicensable
software.
