# Unified legacy compatibility matrix

Telegraphica has one supported product lane: one Cocoa/AppKit `x86_64` app
bundle targeting OS X 10.8 and intended to run through macOS 10.13. Runtime
fallbacks may differ, but source trees, application targets and public release
artifacts must not split by operating-system version.

This matrix separates product intent from evidence for the current candidate.
A local modern-SDK build does not count as a runtime pass.

| System | Runtime lane | Mandatory candidate evidence | Current modernization candidate |
| --- | --- | --- | --- |
| OS X 10.8 Mountain Lion | Mountain Lion TDLib fallback; calls unavailable | unchanged app launch, phone auth/session restore, messages, folders fallback, media fallback, logout/local-data safety, sleep/network recovery | Requires real-system HITL |
| OS X 10.9 Mavericks | Mavericks-and-newer TDLib lane; legacy call module | unchanged app launch, phone/QR/2FA, Keychain prompt, messages/media/folders, audio/video call regression, sleep/network recovery, upgrade install | Requires real-system HITL |
| OS X 10.10 Yosemite | Mavericks-and-newer lane | launch and daily-use smoke using the unchanged candidate | Not yet run for this candidate |
| OS X 10.11 El Capitan | Mavericks-and-newer lane | launch and daily-use smoke using the unchanged candidate | Not yet run for this candidate |
| macOS 10.12 Sierra | Mavericks-and-newer lane | launch and daily-use smoke using the unchanged candidate | Not yet run for this candidate |
| macOS 10.13 High Sierra | Mavericks-and-newer lane | unchanged app launch, auth/session restore, messages/media/folders, notifications, sleep/network recovery and upgrade install | Requires real-system HITL |

## Evidence rules

- Record the app commit, bundle SHA-256, TDLib sidecar metadata and system build.
- Test the same app bundle on every system; rebuilding per system invalidates the
  unified-candidate comparison.
- Deep release gates are 10.8, 10.9 and 10.13. Intermediate systems may use a
  smaller smoke matrix, but an observed failure blocks the unified release.
- Inspect the final executable and every bundled dylib with `file`, `lipo`,
  `otool -l` and `otool -L`. Reject non-`x86_64` dependencies,
  `LC_BUILD_VERSION`, a minimum system newer than the intended lane, or links
  to unavailable system libraries.
- Never infer support from the deployment target, source compatibility, a
  simulator, a VM-only compile, or a previous release's HITL result.

## Capability expectations

The UI reads `TGTDLibCapabilities` and must either hide an unsupported action
or present a calm disabled explanation. Raw TDLib errors are diagnostic data,
not the normal unavailable-feature experience. OS X 10.8 remains in the same
bundle even where a capability such as calls is unavailable.
