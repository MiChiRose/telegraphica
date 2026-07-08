# Telegraphica

Telegraphica is an experimental unofficial Telegram client.

Telegraphica targets OS X 10.9.5 Mavericks on Intel x86_64 and is written in
Objective-C with Cocoa/AppKit. The first milestone is a feasibility report and
a TDLib/Telegram-core spike with local chat-list reads, selected-chat
message-history previews, and a guarded plain-text send path, not a complete
chat UI.

## Current Status

This repository contains an initial legacy AppKit skeleton:

- A minimal programmatic AppKit window that can probe a local `libtdjson.dylib`.
- A dynamic `tdjson` loader so the app can open without vendoring TDLib yet.
- A single background TDLib receiver that routes request responses by `@extra`
  and keeps auth updates from being consumed by the wrong request.
- A state-driven TDLib authorization row and a local chat preview table once
  authorization reaches `ready`.
- A selected-chat message preview table backed by `getChatHistory`.
- A guarded selected-chat plain-text send spike with an explicit confirmation
  dialog and redacted diagnostics.
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

The minimal spike action loads TDLib's JSON interface, executes a synchronous
`getTextEntities` request, asks the async JSON loop for the current
authorization state, and can send local `setTdlibParameters` when TDLib reaches
`waitTdlibParameters`. Telegraphica supports both the TDLib 1.8.0 nested
`setTdlibParameters` shape and the current TDLib flat shape; set
`tdlib_parameters_schema` in the local plist to `auto`, `current`, or `legacy`
when you need to force one lane. When TDLib reaches `waitEncryptionKey`,
Telegraphica
generates or reuses a Keychain-backed database encryption key and sends
`checkDatabaseEncryptionKey`. The spike window can then submit the phone number,
login code, and 2FA password needed to move through `waitPhoneNumber`,
`waitCode`, `waitPassword`, and eventually `ready`. After authorization reaches
`ready`, the spike can run a redacted `getMe`/`getChats` probe to confirm the
session can read basic account and chat-list metadata; this is still a smoke
test. Async TDLib responses are now handled by a single background receiver:
request responses are matched by `@extra`, authorization updates refresh a
cached state summary, and other updates are reduced to bounded in-memory safe
summaries instead of being logged or dumped. The "Load Chats" button then reads
the main chat list and shows a minimal local table with chat title, type, and
unread count. Selecting a chat and clicking "Load Messages" reads recent history
through TDLib and shows local message previews. Selecting a chat, entering text,
and clicking "Send Message" can send a real plain-text Telegram message after an
explicit confirmation dialog. The spike does not auto-retry unconfirmed sends,
send media, edit/delete messages, download media, mark messages as read
intentionally, or persist chat UI state.

Local TDLib parameters are read from:

```text
~/Library/Application Support/Telegraphica/tdlib-config.plist
```

Start from `docs/local-tdlib-config.example.plist`, copy it outside the
repository, and edit the copy with credentials from `my.telegram.org`. Do not
commit the real `api_id`/`api_hash` file, put it in transfer archives, or paste
real values into logs.

## Secrets

Do not commit `api_id`, `api_hash`, phone numbers, login codes, 2FA passwords,
TDLib databases, session files, generated encryption keys, or local credentials.
Do not paste raw TDLib responses from authorization, `getMe`, `getChats`,
`getChat`, or `getChatHistory` into logs, screenshots, issues, or transfer
notes. Chat titles and message previews are local account data; treat
screenshots of the chat/message tables as sensitive too. Use local untracked
configuration and Keychain-backed storage during development.
