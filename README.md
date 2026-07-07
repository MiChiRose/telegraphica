# Telegraphica

Telegraphica is an experimental unofficial Telegram client.

Telegraphica targets OS X 10.9.5 Mavericks on Intel x86_64 and is written in
Objective-C with Cocoa/AppKit. The first milestone is a feasibility report and
a TDLib/Telegram-core spike, not a complete chat UI.

## Current Status

This repository contains an initial legacy AppKit skeleton:

- A minimal programmatic AppKit window that can probe a local `libtdjson.dylib`.
- A dynamic `tdjson` loader so the app can open without vendoring TDLib yet.
- Mavericks-oriented build and compatibility checks.
- Feasibility and security notes for the first milestone.

No official Telegram branding, logos, or assets are included.

## Repository Layout

```text
Telegraphica.xcodeproj/        Xcode project, kept Xcode 6.x-compatible
Sources/                       Objective-C/AppKit source
Sources/Core/                  Telegram core / TDLib boundary
Sources/Services/              Logger and Keychain helpers
Sources/UI/                    Minimal status window
docs/feasibility.md            TDLib/Mavericks feasibility report
docs/security.md               Threat model and local data handling notes
scripts/check_legacy_compat.py Static legacy compatibility checks
scripts/build_tdlib_legacy.sh  TDLib tdjson build helper for Mavericks
scripts/check_tdjson_legacy.sh TDLib dylib compatibility checker
build_legacy.sh                Mavericks/x86_64 build script
```

## Build

Preferred final build lane:

```sh
./build_legacy.sh
```

The script prefers `/Applications/Xcode_6.2.app/Contents/Developer` when it is
installed, targets `MACOSX_DEPLOYMENT_TARGET=10.9`, builds x86_64, stamps
`LSMinimumSystemVersion`, and checks the produced bundle with `otool`, `lipo`,
and `file`.

Modern Xcode can be used for editing and early source checks, but final release
validation must happen on OS X 10.9.5 / Intel with Xcode 6.2 or an equivalent
legacy build lane.

## TDLib Spike

The app currently loads TDLib dynamically. Build or place `libtdjson.dylib` at
one of these locations:

- a path provided by `TELEGRAPHICA_TDJSON_PATH`
- `Telegraphica.app/Contents/Frameworks/libtdjson.dylib`
- `/usr/local/lib/libtdjson.dylib`
- `/opt/homebrew/lib/libtdjson.dylib`
- `libtdjson.dylib`

The first Mavericks target is TDLib `v1.8.0`; `v1.3.0` is the fallback if the
newer tag cannot be built on Xcode 6.2. See `docs/mavericks-transfer.md` for the
hands-on old-Mac flow.

To bundle a built TDLib dylib into the app package:

```sh
TELEGRAPHICA_TDJSON_PATH=/path/to/libtdjson.dylib ./build_legacy.sh
```

The build script copies the dylib to
`Telegraphica.app/Contents/Frameworks/libtdjson.dylib`, runs
`scripts/check_tdjson_legacy.sh`, signs the bundle, and creates the zip.

The minimal spike action calls TDLib's JSON interface and attempts to read the
`version` option. The next milestone is to replace this probe with the real
authorization-state loop.

## Secrets

Do not commit `api_id`, `api_hash`, phone numbers, login codes, TDLib databases,
session files, generated encryption keys, or local credentials. Use local
untracked configuration and Keychain-backed storage during development.
