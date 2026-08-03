# Telegraphica testing

Telegraphica currently uses lightweight test probes instead of an XCTest target.
This keeps the checks compatible with the Mavericks/Xcode 6.2 build lane and
avoids requiring Telegram credentials, Keychain access, TDLib sessions, or real
network calls.

The default runner also compiles and runs the artificial-response TDLib
capability registry probe described in
[tdlib-capabilities.md](tdlib-capabilities.md).

## Existing checks

- `scripts/check_legacy_compat.py` scans project source for legacy macOS/Xcode
  hazards, committed secrets, project settings, local-data reset safety, and
  diagnostic log redaction.
- `scripts/check_free_feature_policy.py` rejects Telegram payment, Premium,
  Stars, gift, boost, paid-message and giveaway TDLib request types.
- `scripts/check_media_item_support.sh` compiles `Tests/media_item_support_probe.m`
  and verifies the media-preview gate: photos/videos can preview, stickers and
  documents do not open the media preview.
- `scripts/check_webp_legacy.sh` and `scripts/check_tgs_legacy.sh` compile
  decoder/view probes for WebP and TGS/WebM support. These are intentionally
  heavier and remain separate from the fast default test run.
- `build_legacy.sh` runs both policy scanners and
  `check_media_item_support.sh` before building the app.
- `scripts/check_tdlib_build_metadata.sh` verifies that a TDLib build sidecar
  matches the bundled binary and its recorded exported-C-ABI list. The release
  bundle audit runs this check for both runtime lanes.
- The Xcode scheme has an empty `TestAction`; there is no XCTest target yet.

## Fast local tests

Run:

```sh
./scripts/run_tests.sh
```

The script runs:

- legacy compatibility checks;
- static project checks for localization coverage, source membership in the
  Xcode project, required test files, and committed runtime-data guards;
- shell syntax checks for build/test scripts;
- `git diff --check`;
- a local mock TDLib event reducer probe;
- the media preview gate probe;
- a compiled Objective-C core logic probe covering themes, display preferences,
  resource policy limits, media type handling, outgoing text chunking,
  localization fallback, and message layout sizing.
- a compiled media image-loader probe covering display-size downsampling,
  source-version cache invalidation, main-thread delivery of asynchronous
  decode results, bounded message-thumbnail prefetch deduplication and cache
  reset invalidation.
- a compiled animated-image probe covering off-main GIF validation/decode,
  main-thread delivery, bounded caching and cancellation suppression.
- a static sticker-thumbnail pipeline check ensuring that picker layout only
  reads the bounded cache and that grid/rail jobs are cancellable and reject
  stale generations.
- a custom-emoji fixture probe covering identifier collection, TDLib sticker
  response parsing, completed-file gating, and fail-closed malformed data.
- an advanced chat-folder fixture probe covering multiple invite-link parsing,
  recommended folder conversion, server-option limits, malformed responses and
  legacy-safe identifier normalization.
- a persistent download-queue probe covering interrupted-state restoration,
  bounded property-list serialization and TDLib file identifier retention.
- a storage-cleanup policy probe covering TDLib file-type objects, grouped
  video categories, and bounded/deduplicated chat identifiers.
- a playback-speed preference probe covering bounded legacy-safe rates,
  independent audio/video persistence, and the opt-in sequential-audio
  preference;
- a sequential-audio fixture probe covering same-chat ordering, video and
  foreign-chat skips, identifier recovery, and end-of-sequence behavior;

The probe process uses a temporary `HOME` so `NSUserDefaults` writes do not touch
the real Telegraphica profile.

## Optional launch smoke

After building the app, run:

```sh
./scripts/smoke_launch_app.sh
```

or pass an app path:

```sh
./scripts/smoke_launch_app.sh build-legacy/Release/Telegraphica.app
```

The smoke launch starts the app with an isolated temporary `HOME`, waits a few
seconds, verifies that the process did not crash or quit immediately, then
terminates it. It does not delete or modify the real
`~/Library/Application Support/Telegraphica` directory.

Because Telegraphica is a GUI app and the production client may still attempt
normal startup work, this smoke check is separate from the default fast tests.
Manual HITL on Mavericks remains required for login, Keychain prompts, TDLib
authorization, media playback, and real chat behavior.

## Telegram test DC

TDLib exposes `use_test_dc` in `setTdlibParameters`, and Telegram documents
reserved test phone numbers for Test DC authorization flows. That environment is
useful for a future opt-in integration test, but it is still a live Telegram
network flow with API credentials, a TDLib database, and authorization state. It
is deliberately not part of `run_tests.sh`.

## Current gaps

- No XCTest target is present.
- TDLib networking and authorization are deliberately not exercised by automated
  tests.
- Pixel-perfect UI assertions, FPS/CPU thresholds, Instruments analysis, and
  full chat/media workflows remain manual or HITL checks.
- WebP/TGS decoder probes are available but not part of the fast default test
  run because they build third-party libraries.
