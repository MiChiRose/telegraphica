# Unified OS X 10.8–10.13 release checklist

Use this checklist only after the user explicitly requests a release. The
candidate is one unchanged `x86_64` app bundle and one canonical artifact set
named `macos10.8-10.13-x86_64`.

## 1. Source and policy gate

- [ ] Release commit is reviewed and reachable from `develop`.
- [ ] HITL approval exists before merging `develop` to `main`.
- [ ] Worktree is clean; unrelated user files are not staged.
- [ ] `./scripts/run_tests.sh` passes.
- [ ] `scripts/check_webp_legacy.sh` and `scripts/check_tgs_legacy.sh` pass.
- [ ] Localization/static project checks pass.
- [ ] Free-feature policy passes; no payment or Premium transaction path exists.
- [ ] Secret scan finds no API credentials, phone numbers, login codes,
  Keychain values, TDLib databases or session data.
- [ ] MRC ownership, background callbacks, cancellation and main-thread disk
  I/O receive an explicit review for the changed surface.

## 2. Build and binary gate

- [ ] Build once with the documented legacy toolchain and deployment target
  10.8; do not create OS-specific app variants.
- [ ] Main executable and every nested binary are Intel `x86_64`.
- [ ] Main executable and compatible nested binaries use
  `LC_VERSION_MIN_MACOSX`; no legacy release binary contains
  `LC_BUILD_VERSION`.
- [ ] `otool -L` lists no unavailable modern-only system dependency.
- [ ] Both TDLib lanes pass `scripts/check_tdlib_build_metadata.sh` and have
  recorded version, source tag/commit, MTProto layer, SHA-256 and exported
  tdjson ABI.
- [ ] The app contains no build-machine absolute paths or credentials.
- [ ] HFS+ DMG, app ZIP and SHA-256 files are produced with the canonical
  complete-range names.

## 3. Account-free smoke

- [ ] Launch smoke completes with an isolated temporary `HOME`.
- [ ] Settings and retained utility windows open, close and reopen without
  stale callbacks: profile, folders, downloads, storage, sessions, privacy,
  chat information, administration, scheduled messages, media and QR login.
- [ ] Unsupported capability states are hidden or explained; no raw TDLib
  request error is the primary UI.

## 4. Deep real-system HITL

Run the exact same app bundle on OS X 10.8, OS X 10.9 and macOS 10.13. Record
system build, app SHA-256, TDLib lane and result in the release notes.

- [ ] Clean install and first launch.
- [ ] Upgrade over the preceding public version without losing the session.
- [ ] Phone login, Telegram code and 2FA.
- [ ] QR login where the runtime capability is available, including cancel and
  return to phone login.
- [ ] Session restoration after app restart and Keychain prompt handling.
- [ ] Chat list, archive, contacts, folders and runtime-gated folder actions.
- [ ] Receive/send/edit/delete/reply/forward messages and read-state handling.
- [ ] Photos, documents, stickers, voice, video and download restoration.
- [ ] Notifications, mute state and background/tray behavior.
- [ ] Sleep/wake, network loss, reconnection and proxy/VPN regression.
- [ ] Audio/video calls on the supported lane; clear unavailable state on 10.8.
- [ ] Logout and narrowly scoped removal of local Telegraphica data.

## 5. Intermediate-system smoke

- [ ] The unchanged candidate launches on 10.10, 10.11 and 10.12 when those
  systems are available.
- [ ] A basic session/chat/message/media smoke passes, or any missing machine is
  explicitly recorded as untested rather than claimed supported by evidence.

## 6. Publication gate

- [ ] Final release notes distinguish automated checks, real-system HITL and
  untested surfaces.
- [ ] Known capability limits and TDLib rollback path are linked.
- [ ] Checksums match uploaded assets after download.
- [ ] No older scratch archive is mistaken for the candidate; obsolete
  Telegraphica-only build clutter is removed with exact-path cleanup.
- [ ] `main` merge and GitHub publication occur only after explicit user
  authorization.

If a candidate fails any supported system, fix the shared source/runtime gate
or stop for a product decision. Do not silently create a second release lane.
