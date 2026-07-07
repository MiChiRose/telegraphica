# Telegraphica Feasibility Report

Date: 2026-07-07

Telegraphica is an experimental unofficial Telegram client for OS X 10.9.5
Mavericks, Intel x86_64, Objective-C/Cocoa/AppKit, and Xcode 6.2 where
possible. This first milestone is about proving the Telegram core, not building
a polished chat UI.

## Recommendation

Use TDLib through the JSON C API (`tdjson`) as the first backend path. Do not
write MTProto from scratch.

The recommended spike order is:

1. Build TDLib v1.8.0 `tdjson` for x86_64 with `CMAKE_OSX_DEPLOYMENT_TARGET=10.9`.
2. If v1.8.0 fails on the Mavericks lane, test TDLib v1.3.0 as a compatibility fallback.
3. Treat current TDLib `master` as a future-track option, not the first Mavericks target.
4. Load `libtdjson.dylib` dynamically from the AppKit app and run a version/auth-state probe.

## TDLib Findings

Current TDLib documentation says TDLib is cross-platform, exposes a JSON C
interface usable from languages that can call C functions, handles network
details, encryption, and local storage, and depends on C++17, OpenSSL, zlib,
gperf, and CMake 3.10+.

Older tagged TDLib snapshots are more plausible for Xcode 6.2:

| TDLib path | Local evidence | Mavericks assessment |
| --- | --- | --- |
| Current `master` | Official README requires C++17-compatible compiler and CMake 3.10+. | Not a good first target for Xcode 6.2. Try later with a modern cross-build only if the output is proven 10.9-safe. |
| v1.8.0 | Tagged Dec 29, 2021. README requires C++14, OpenSSL, zlib, gperf, CMake 3.0.2+. CMake builds `tdjson` and `tdjson_static`. | Best first attempt: newest tagged release while still C++14. Must verify compiler, libc++, OpenSSL, and Mach-O min version on Mavericks. |
| v1.3.0 | Tagged Sep 5, 2018. README also requires C++14, OpenSSL, zlib, gperf, CMake 3.0.2+. | Compatibility fallback if v1.8.0 fails. Higher protocol/API staleness risk. |

The JSON interface is the right boundary for Objective-C. TDLib v1.8.0 exports
`td_json_client_create`, `td_json_client_send`, `td_json_client_receive`,
`td_json_client_execute`, and `td_json_client_destroy`; it also has the newer
client-id JSON functions. TDLib v1.3.0 has the older pointer-based JSON API, so
Telegraphica should keep a wrapper around the pointer-based API first.

## Architecture

Keep the project split into small legacy-safe layers:

```text
AppDelegate
  TGStatusWindowController
    status / TDLib probe UI
  TGTDLibClient
    dynamic loading of libtdjson.dylib
    JSON request/response boundary
  TGKeychainHelper
    future TDLib database encryption key storage
  TGLogger
    redacted, opt-in diagnostics
```

Later, the TDLib layer should become:

```text
TGTelegramCore
  TGTDLibClient
  TGAuthorizationController
  TGChatStore
  TGMessageStore
  TGMediaStore
```

Use model objects that are plain Objective-C classes. Avoid Objective-C
generics, nullability annotations, Swift, SwiftUI, `@available`, and macOS
10.10+ AppKit conveniences.

## Minimal UI Scope

For the first spike, keep one `NSWindowController` with a status label, log
output, and a "Check TDLib" action. Do not build the full Telegram UI yet.

The eventual Mavericks-safe layout should use:

- `NSWindow`, `NSWindowController`, `NSView`
- `NSSplitView` owned manually, not `NSSplitViewController`
- `NSTableView` for chat list
- read-only `NSTextView` or table-backed transcript for messages
- `NSTextView` composer plus `NSButton`

Avoid `NSVisualEffectView`, `NSStoryboard`, `NSSplitViewController`,
`NSLayoutAnchor`, `activateConstraints:`, full-size titlebar APIs, and automatic
row-height assumptions.

## Syncrosa Patterns To Reuse

Use the `syncrosa-objc` project as an engineering style reference:

- `build_legacy.sh` structure: strict shell, Xcode 6.2 preference, `10.9`
  deployment target, x86_64, isolated DerivedData, `PlistBuddy`, `otool`,
  `lipo`/`file`, coverage-section checks, ad-hoc signing, zip packaging.
- Info.plist discipline: explicit version fields, bundle id, and
  `LSMinimumSystemVersion`.
- Project settings: `objectVersion = 46`, `compatibilityVersion = "Xcode 3.2"`,
  `MACOSX_DEPLOYMENT_TARGET = 10.9`, `SDKROOT = macosx`, coverage off.
- Keychain helper pattern: `kSecClassGenericPassword`, service/account split,
  save/read/delete.
- Logger pattern: bounded in-memory log, opt-in diagnostics, synchronized file
  append, session header.
- NSTask/curl fallback ideas: if a later non-TDLib network helper is needed,
  use temp config files and avoid secrets in process arguments.
- Localization/settings pattern: saved language and defaults can be reused, but
  keep one source of truth for strings.

## Syncrosa Patterns Not To Reuse

Do not copy:

- Music/iTunes/library models, controllers, AppleScript business logic, or USB
  export flows.
- AI provider code, prompts, or model settings.
- Any Syncrosa service names, bundle identifiers, credentials, assets, or UI
  text.
- Mach-O patching scripts. Prefer fail-fast build checks.
- A large tabbed UI before the TDLib spike is proven.

## Compatibility Risks

- Xcode 6.2 may not build even C++14 TDLib cleanly despite the nominal compiler
  requirement. This must be tested on the real lane.
- A TDLib built on Apple Silicon or a modern macOS SDK can silently produce
  incompatible load commands or libc++/libSystem requirements.
- OpenSSL built by modern Homebrew may not target Mavericks. Build OpenSSL/zlib
  for x86_64 and inspect load commands.
- TDLib transitive dependencies may use APIs unavailable on OS X 10.9.
- Modern Xcode may reject `MACOSX_DEPLOYMENT_TARGET=10.9` or emit
  `LC_BUILD_VERSION`; final validation must use Mavericks/Xcode 6.2.
- Old TDLib may compile but fail against current Telegram API expectations.
- Static linking may ease deployment but can increase binary size and licensing
  review surface; dynamic linking simplifies spike iteration.

## Security Risks

Security details live in `docs/security.md`. The highest-priority controls for
the spike are:

- Never commit or log `api_id`, `api_hash`, phone numbers, login codes, 2FA
  passwords, session files, or TDLib databases.
- Generate a high-entropy TDLib database encryption key and store only that key
  in Keychain.
- Keep TDLib database and files under explicit per-user directories in
  `~/Library/Application Support/Telegraphica/` and
  `~/Library/Caches/Telegraphica/`.
- Keep diagnostics opt-in and redacted.

## MVP Scope

1. Login flow through TDLib authorization states.
2. Session storage with explicit TDLib directories and Keychain-backed database
   encryption key.
3. Chat list using TDLib chat updates.
4. Read latest messages in a selected chat.
5. Send a text message.
6. Basic media download later, after cache/privacy controls exist.

## Build And Release Strategy

Development can happen on Apple Silicon, but release confidence requires:

1. Build/check Objective-C app source on the development machine.
2. Build TDLib `tdjson` for x86_64 with `CMAKE_OSX_ARCHITECTURES=x86_64` and
   `CMAKE_OSX_DEPLOYMENT_TARGET=10.9`.
3. Inspect TDLib and app binaries with `file`, `lipo -archs`, and `otool -l`.
4. Ensure app binary uses `LC_VERSION_MIN_MACOSX` with version `10.9`, not a
   modern-only load command.
5. Run on OS X 10.9.5 Intel hardware or VM.
6. Verify login, restart/session reuse, logout, local data deletion, and a text
   send/receive loop.

For the hands-on Mavericks TDLib build, package, and probe recipe, see
`docs/mavericks-transfer.md`.

## Minimal Spike Plan

1. Build `tdjson` from TDLib v1.8.0.
2. Place `libtdjson.dylib` in `Telegraphica.app/Contents/Frameworks/` or set
   `TELEGRAPHICA_TDJSON_PATH`.
3. Launch Telegraphica and run the "Check TDLib" probe.
4. Replace the probe with a TDLib receive loop on a dedicated background thread.
5. Send `setTdlibParameters` with explicit database/files directories, local
   language, app version, device model, `api_id`, and `api_hash` loaded from
   local untracked config/Keychain.
6. Handle `authorizationStateWaitPhoneNumber`,
   `authorizationStateWaitCode`, `authorizationStateWaitPassword`, and
   `authorizationStateReady`.
7. Only after auth state is proven, build chat list and message transcript UI.

## Primary Sources

- TDLib repository and README: https://github.com/tdlib/td
- TDLib build instructions: https://tdlib.github.io/td/build.html
- TDLib JSON C API docs: https://core.telegram.org/tdlib/docs/td__json__client_8h.html
- TDLib v1.8.0 tag: https://github.com/tdlib/td/releases/tag/v1.8.0
- TDLib v1.3.0 tag: https://github.com/tdlib/td/releases/tag/v1.3.0
- Telegram API app creation: https://core.telegram.org/api/obtaining_api_id
- Telegram API Terms of Service: https://core.telegram.org/api/terms
