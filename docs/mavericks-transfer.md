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

Expected result without TDLib: the app opens, shows the Telegraphica core spike
window, and the "Check TDLib" button reports that `libtdjson.dylib` cannot be
loaded. That is OK for the first UI/core-shell smoke test.

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

After the config exists, run the app again and click "Check TDLib". Expected
result for this milestone:

- `TDLib auth state: waitTdlibParameters`;
- `TDLib parameters: ... waitEncryptionKey`;
- `TDLib encryption key: ... waitPhoneNumber`.

Telegraphica generates the TDLib database encryption key locally and stores only
that key in Keychain. The key value must never be copied into screenshots, logs,
shell commands, or transfer archives. Re-run the app after this step to confirm
the Keychain key is reused and TDLib advances past `waitEncryptionKey` again.

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

Useful options:

```sh
--clean                 remove the previous TDLib build directory first
--jobs 2                lower parallelism if the old Mac is memory constrained
--zlib-root /path       use a custom zlib prefix
--no-patch-legacy-linker
                        keep TDLib's Apple linker strip flags unchanged
--no-patch-fdopendir    keep TDLib's fdopendir-based directory walk unchanged
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

## Important

Do not enter or save real Telegram `api_id`, `api_hash`, phone numbers, login
codes, or TDLib session data in this repository. Real login flow has not been
implemented yet.

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
