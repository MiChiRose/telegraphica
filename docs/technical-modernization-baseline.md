# Telegraphica technical-modernization baseline

Recorded before the first capability-registry implementation on 2026-08-03.

## Source baseline

- Branch base: `develop`
- Revision: `0fe804f0fe4dd9b6e1e23253864a1e0cfbe06ec5`
- Product lane: one Objective-C/AppKit x86_64 application for OS X 10.8 through macOS 10.13.
- Local diagnostic toolchain: Xcode 26.6, Apple clang 21.0.0, CMake 4.4.1, Python 3.9.6.
- Release compilation remains owned by the documented Xcode 5.1.1/Xcode 6.2 legacy workflow; the local modern toolchain is not release proof.

## Tests before implementation

`./scripts/run_tests.sh` passed in full:

- legacy compatibility and free-feature policy;
- static project and security-hardening checks;
- shell syntax and whitespace;
- mock TDLib event reducer;
- Workshop game, installer, validator, and media-workbench tests;
- media-preview gate;
- core Objective-C logic probe.

## Bundled TDLib lanes observed in the latest verified app

| Lane | Binary | Install name | Minimum OS | Architecture | SHA-256 |
|---|---|---|---|---|---|
| Mountain Lion fallback | `libtdjson-mountain-lion.dylib` | `@rpath/libtdjson.1.8.0.dylib` | 10.8 | x86_64 | `8968fb64179dc30bc562fc9efc3376688c6f76b4f49dc8734e63c76c258e8eb7` |
| Mavericks and newer | `libtdjson.dylib` | `@rpath/libtdjson.1.8.65.dylib` | 10.9 | x86_64 | `1e99d9096fd9a2c133c1a66bf7269b3cb51011a57dae223f0c7ec3c5e1f0fea6` |

Both libraries link only to the expected legacy system C++ and System libraries in the inspected release bundle. The existing release manifest already records architecture, minimum OS, install name, bundle path, and digest. It does not yet record the TDLib source commit/tag or MTProto layer; that belongs to the TDLib-build modernization stage.

## Current code shape

- `Sources/Core/TGTDLibClient.m`: 11,632 lines.
- All `TGTDLibClient+*.m` feature categories: 3,777 lines.
- `Sources/UI/TGStatusWindowController.m`: 5,054 lines.
- `TGStatusWindowController+*.inc`: 20,459 lines.

The main client currently owns dynamic loading, tdjson transport, request correlation, bounded response/update queues, authorization state, chat caches, response parsing, and a significant amount of feature transformation. The status controller and its includes still combine auth, chat list, message list, composer, media, search, settings, and auxiliary windows.

## Existing TDLib surface

The code already sends requests across these established areas:

- authorization: phone, QR, code, password, logout;
- chats and contacts: private/basic group/supergroup/secret chat creation, invites, archive/leave/delete, contacts;
- messages: history, search, send/edit/delete/forward/reply/pin/read state, reactions, polls, drafts;
- media: photo/video/audio/document/animation/sticker/voice/video-note/location/venue/contact/dice, albums, download/cancel/cache;
- folders: legacy chat filters plus modern chat folders, ordering, shared-folder import and invite links;
- forums and administration: topics, members, rights, bans, invite links, join requests, event log, slow mode;
- notifications, privacy, sessions, saved-message topics, bots, scheduled messages, and calls.

This inventory is an implementation surface, not a support claim. Before this modernization, feature availability was inferred locally by individual call sites, fallback request attempts, response-property checks, or the loaded dylib filename. It lacked one cached, explainable runtime capability source.

## Lane differences before the registry

- Runtime OS detection selects `libtdjson-mountain-lion.dylib` on 10.8 and `libtdjson.dylib` on 10.9+.
- The 10.8 lane uses separate TDLib database/files directories and migration safeguards.
- Chat-folder code inspects the loaded filename directly to prefer legacy `chatFilter` requests on 10.8 and modern `chatFolder` requests otherwise.
- The modern call transport is a separately verified 10.9+ component; calls remain gated off on 10.8.
- Several UI paths use local schema/property checks and fallback requests rather than a shared capability result.

The first modernization increment replaces this scattered lane inference where it can do so safely, without changing the verified call transport or user session storage.

## Incremental architecture progress

Message-search request building, schema fallbacks and response validation have
been moved from the main client into `TGTDLibClient+Search`. Transport ownership
and message-model conversion stay in the main client, and a fixture probe locks
the request contract before additional search surfaces are migrated.

Storage statistics and cache cleanup now live in `TGTDLibClient+Storage`.
Filtered `optimizeStorage` construction, chat-scope normalization and the
post-cleanup statistics refresh are locked by an account-free fixture probe.

Download, cancellation and cache-file deletion now live in
`TGTDLibClient+Files`; media and download surfaces import this focused API and
an account-free fixture probe locks its TDLib request contract.
