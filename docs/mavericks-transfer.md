# Mavericks Transfer Instructions

This archive is intended for OS X 10.9.5 Mavericks / Intel x86_64 validation.

## What To Do On The Old Mac

1. Unzip the archive.
2. Open Terminal.
3. Go into the unzipped folder:

```sh
cd Telegraphica-develop-<commit>
```

4. Build the legacy AppKit spike:

```sh
./build_legacy.sh
```

5. Run the produced app:

```sh
open build-legacy/Release/Telegraphica.app
```

Expected result without TDLib: the app opens, shows the Telegraphica chat shell
window with a left chat pane, right message pane, compact diagnostics area, and
the "Check TDLib" button reports that `libtdjson.dylib` cannot be loaded. That
is OK for a UI/core-shell smoke test.

## If You Have libtdjson.dylib

If a Mavericks-compatible `libtdjson.dylib` has already been built, test it with
the project checker:

```sh
./scripts/check_tdjson_legacy.sh /path/to/libtdjson.dylib
```

Then rebuild Telegraphica and bundle the dylib into the app:

```sh
TELEGRAPHICA_TDJSON_PATH=/path/to/libtdjson.dylib ./build_legacy.sh
open build-legacy/Release/Telegraphica.app
```

When bundling TDLib, `build_legacy.sh` treats unresolved non-system dylib
dependencies as an error. If this fails, rebuild TDLib with static OpenSSL/zlib
or copy and rewrite the dependent dylibs before sharing the app bundle.

Click "Check TDLib". A successful spike should show that TDLib was loaded, that
the synchronous JSON probe completed, and that the async authorization-state
probe returned a TDLib state.

## Local TDLib Parameters

To advance past `authorizationStateWaitTdlibParameters`, copy the example
configuration outside the repository and edit the copy:

```sh
mkdir -p "$HOME/Library/Application Support/Telegraphica"
cp docs/local-tdlib-config.example.plist "$HOME/Library/Application Support/Telegraphica/tdlib-config.plist"
open -e "$HOME/Library/Application Support/Telegraphica/tdlib-config.plist"
```

Replace the placeholder `api_id` and `api_hash` with values from
`my.telegram.org`. Do not save real credentials in the repository, screenshots,
transfer archives, or shell history.

Keep `tdlib_parameters_schema` set to `auto` unless you are diagnosing a
specific TDLib build. Use `current` for a current TDLib master dylib and
`legacy` for TDLib 1.8.0.

After the config exists, run the app again and click "Check TDLib". Expected
result for this milestone:

- `TDLib auth state: waitTdlibParameters`;
- `TDLib parameters: ... waitEncryptionKey`;
- `TDLib encryption key: ... waitPhoneNumber`.

Telegraphica generates the TDLib database encryption key locally and stores only
that key in Keychain. The key value must never be copied into screenshots, logs,
shell commands, or transfer archives. Re-run the app after this step to confirm
the Keychain key is reused and TDLib advances past `waitEncryptionKey` again.

For the next auth milestone, the window exposes one auth input row at a time:

- `Phone` when TDLib reports `waitPhoneNumber`;
- `Code` when TDLib reports `waitCode`;
- `Password` when TDLib reports `waitPassword`;
- no input when TDLib reports `ready`.

When TDLib reports `ready`, "Check TDLib" should run a redacted `getMe`/`getChats`
probe and report only generic success plus chat count, not raw account or chat
JSON.

After clicking "Check TDLib", the details view should include a line like:

```text
TDLib receiver: receiver active; pending responses: 0; waiting responses: 0; queued safe updates: ...
```

The counts are diagnostic only. They must not include raw TDLib JSON, chat
titles, phone numbers, message text, or IDs.

After TDLib reports `ready`, click "Load Chats". Expected result:

- the status changes to `TDLib chats: loaded`;
- the left chat table fills with up to 10 main chat previews;
- the details view reports only the number of loaded previews, not chat titles
  or raw TDLib JSON.

Select a row in the chat table and click "Load Messages". Expected result:

- the status changes to `TDLib messages: loaded`;
- the right message table fills with recent previews for the selected chat;
- the details view reports only the number of loaded previews, not message text
  or raw TDLib JSON.

To test the text-send spike, choose a harmless destination first, preferably
Saved Messages or a private test chat:

1. Select the chat.
2. Type a short harmless message in the `Send` field.
3. Click "Send Message".
4. Read the confirmation dialog carefully. It is a real Telegram send, not a
   dry run.
5. Click "Send" only if the selected chat is correct. Do not use Return/Enter
   to confirm the send dialog during this spike.

Expected result:

- the status changes to `TDLib send: accepted`;
- the send field clears;
- the message table reloads and should show the new message if TDLib returns it
  in recent history;
- the details view reports only generic send status, not the message text or raw
  TDLib JSON.

If the status changes to `TDLib send: not confirmed`, do not immediately press
"Send Message" again. TDLib may have sent the message even if the synchronous
confirmation timed out. Check the selected chat from another Telegram client or
reload messages first.

The tables display local account data. Do not post screenshots of real chat
titles, unread counts, message previews, or account metadata outside the private
validation loop.

Do not include the real phone number, login code, or 2FA password in screenshots,
logs, shell history, or transfer archives. The details view should show only
generic submit results and TDLib auth states.

You can also test an explicit dylib path without bundling:

```sh
TELEGRAPHICA_TDJSON_PATH=/path/to/libtdjson.dylib build-legacy/Release/Telegraphica.app/Contents/MacOS/Telegraphica
```

## Building TDLib On Mavericks

Start with TDLib `v1.8.0`. If that tag cannot be built with Xcode 6.2, use
TDLib `v1.3.0` as the compatibility fallback.

Prerequisites on the old Mac:

- OS X 10.9.5 on Intel x86_64.
- Xcode 6.2 or the closest legacy build lane.
- CMake, `gperf`, `make`, and command line tools.
- OpenSSL headers/libs built for x86_64 and OS X 10.9.
- zlib from the system SDK, or a custom zlib prefix built for x86_64 and 10.9.

Use a local TDLib source checkout or archive. The script intentionally does not
download source code, because old TLS/network support on Mavericks is often the
least reproducible part of the process.

From a TDLib checkout:

```sh
./scripts/build_tdlib_legacy.sh \
  --source /path/to/td \
  --openssl-root /path/to/openssl-prefix
```

From a TDLib release archive:

```sh
./scripts/build_tdlib_legacy.sh \
  --archive /path/to/td-v1.8.0.tar.gz \
  --openssl-root /path/to/openssl-prefix
```

Fallback attempt with TDLib `v1.3.0`:

```sh
TDLIB_VERSION=v1.3.0 ./scripts/build_tdlib_legacy.sh \
  --archive /path/to/td-v1.3.0.tar.gz \
  --openssl-root /path/to/openssl-prefix
```

If login reaches `waitPhoneNumber` but Telegram rejects the phone submit with
`UPDATE_APP_TO_LOGIN`, the TDLib/API layer is probably too old for current
server login policy. In that case, keep Mavericks but try a newer TDLib source
snapshot. This is experimental: it may require newer CMake/C++ compiler support
than Xcode 6.2 can provide.

Prepare the archive on a newer Mac if Mavericks cannot download it reliably:

```sh
curl -L -o ~/Desktop/td-master.tar.gz https://github.com/tdlib/td/archive/refs/heads/master.tar.gz
```

Then transfer `td-master.tar.gz` to the old Mac and build it from the unzipped
Telegraphica folder:

```sh
TDLIB_VERSION=master-snapshot ./scripts/build_tdlib_legacy.sh \
  --archive ~/Desktop/td-master.tar.gz \
  --openssl-root /opt/local \
  --build-dir build-tdlib-master-legacy \
  --clean \
  --allow-snapshot
```

If CMake reports `No C++17 support in the compiler`, Xcode 6.2's AppleClang is
too old for the current TDLib snapshot. Install a newer compiler through
MacPorts and retry with `CC`/`CXX` pointing at that compiler:

```sh
sudo port selfupdate
sudo port install clang-17
ls /opt/local/bin/clang*mp-17
```

Then rebuild the snapshot from a clean build directory:

```sh
CC=/opt/local/bin/clang-mp-17 \
CXX=/opt/local/bin/clang++-mp-17 \
TDLIB_VERSION=master-snapshot \
./scripts/build_tdlib_legacy.sh \
  --archive ~/Desktop/td-master.tar.gz \
  --openssl-root /opt/local \
  --build-dir build-tdlib-master-legacy \
  --clean \
  --allow-snapshot
```

Use `--clean` or a new `--build-dir` whenever changing compilers, because CMake
caches the compiler selected during the first configure. Run the script as
`./scripts/build_tdlib_legacy.sh` or `bash ./scripts/build_tdlib_legacy.sh`, not
with `sh`.

If `clang-17` is unavailable on that MacPorts installation, try `clang-16` or
`clang-15` and adjust the `CC`/`CXX` paths accordingly. A newer compiler can get
past TDLib's C++17 configure check, but the old Mavericks SDK/libc++ may still
fail later if current TDLib uses newer library features. The resulting dylib
still must pass `scripts/check_tdjson_legacy.sh`; otherwise it is not safe to
bundle for Mavericks.

If this succeeds, bundle the resulting dylib exactly like the v1.8.0 build:

```sh
TELEGRAPHICA_TDJSON_PATH=build-tdlib-master-legacy/stage/Frameworks/libtdjson.dylib ./build_legacy.sh
open build-legacy/Release/Telegraphica.app
```

If the newer TDLib build fails, keep `build-tdlib-master-legacy/build.log`; that
log is the next thing to inspect. Do not include Telegram credentials, phone
numbers, login codes, 2FA passwords, or TDLib database files in any transferred
archive.

Useful options:

```sh
--clean                 remove the previous TDLib build directory first
--jobs 2                lower parallelism if the old Mac is memory constrained
--zlib-root /path       use a custom zlib prefix
--no-patch-legacy-linker
                        keep TDLib's Apple linker strip flags unchanged
--no-patch-fdopendir    keep TDLib's fdopendir-based directory walk unchanged
--no-patch-clock-gettime
                        keep TDLib's POSIX clock_gettime debug code unchanged
--allow-unknown-tag     continue if the script cannot prove the TDLib tag
```

On Xcode 6.2, TDLib's default Apple linker strip flags can trigger an internal
`ld` error while building helper tools such as `generate_mime_types_gperf`. The
script patches those flags out of the extracted TDLib source by default before
running CMake. The original archive is not modified. If you are testing a newer
toolchain and want the upstream flags untouched, pass `--no-patch-legacy-linker`.

The OS X 10.9 SDK also does not declare `fdopendir`, which TDLib v1.8.0 uses in
its POSIX directory walk helper. The script patches the extracted source to close
the already-open file descriptor and use TDLib's existing path-based `opendir`
fallback. This is a Mavericks compatibility shim for the spike, not a general
upstream replacement.

Current TDLib snapshots can also use `clock_gettime` and `clockid_t` while
building debug clock output. OS X 10.9 SDK does not provide those symbols, so
the script skips that TDLib debug clock enumeration on Apple legacy builds and
leaves TDLib's existing `std::chrono::steady_clock` fallback in place.

Expected output:

```text
build-tdlib-legacy/stage/Frameworks/libtdjson.dylib
build-tdlib-legacy/build.log
build-tdlib-legacy/validation.txt
```

Then bundle that output into Telegraphica:

```sh
TELEGRAPHICA_TDJSON_PATH=build-tdlib-legacy/stage/Frameworks/libtdjson.dylib ./build_legacy.sh
open build-legacy/Release/Telegraphica.app
```

Click "Check TDLib". Expected success:

- the status changes to `TDLib status: loaded`;
- the details include `Loaded:`;
- the details include `TDLib probe: sync execute OK ...`;
- the details include `TDLib auth state: ...`;
- if local TDLib config exists, the details include `TDLib parameters: ...`;
- if TDLib reaches `waitEncryptionKey`, the details include `TDLib encryption key: ...`.
- if TDLib reaches `waitPhoneNumber`, the auth row allows submitting phone,
  then code, then 2FA password if required.
- if TDLib reaches `ready`, the details include a redacted `getMe`/`getChats`
  probe result with account-probe success and chat count.
- after clicking "Load Chats", the lower table shows local chat previews and the
  details include only a generic loaded-count line.
- after selecting a chat and clicking "Load Messages", the message table shows
  recent previews fetched via TDLib and shown only in the local UI; the details
  include only a generic loaded-count line.

## Important

Do not enter or save real Telegram `api_id`, `api_hash`, phone numbers, login
codes, 2FA passwords, or TDLib session data in this repository.

Builds produced by modern Xcode on a modern Mac are smoke tests only. The useful
compatibility result comes from running `./build_legacy.sh` on OS X 10.9.5 /
Intel with Xcode 6.2 or the closest available legacy lane.

A dylib built on a modern Mac can still be wrong for Mavericks even if it is
x86_64. Reject builds that contain `LC_BUILD_VERSION` or require a minimum
macOS newer than 10.9. If `otool -L` or `scripts/check_tdjson_legacy.sh` reports
non-system dependencies, treat that as unresolved packaging work before sharing
a portable app bundle. Prefer rebuilding TDLib with static OpenSSL/zlib;
otherwise copy those dylibs into `Contents/Frameworks` and rewrite their
references with `install_name_tool` to `@loader_path/...`.

A public installer must be created from an app bundle that already contains a
Mavericks-compatible `Contents/Frameworks/libtdjson.dylib`. Do not publish a DMG
that asks end users to install CMake, MacPorts, OpenSSL, or TDLib separately:
those are build inputs, not normal runtime installation steps.
