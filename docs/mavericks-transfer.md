# Mavericks Transfer Instructions

This archive is intended for OS X 10.9.5 Mavericks / Intel x86_64 validation.

## What To Do On The Old Mac

1. Unzip the archive.
2. Open Terminal.
3. Go into the unzipped folder:

```sh
cd Telegraphica-develop
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

If a Mavericks-compatible `libtdjson.dylib` has already been built, test it with:

```sh
file /path/to/libtdjson.dylib
lipo -archs /path/to/libtdjson.dylib
otool -l /path/to/libtdjson.dylib | grep -A3 LC_VERSION_MIN_MACOSX
otool -L /path/to/libtdjson.dylib
```

Then launch Telegraphica with:

```sh
TELEGRAPHICA_TDJSON_PATH=/path/to/libtdjson.dylib build-legacy/Release/Telegraphica.app/Contents/MacOS/Telegraphica
```

Click "Check TDLib". A successful spike should show the loaded TDLib version.

## Important

Do not enter or save real Telegram `api_id`, `api_hash`, phone numbers, login
codes, or TDLib session data in this repository. Real login flow has not been
implemented yet.

Builds produced by modern Xcode on a modern Mac are smoke tests only. The useful
compatibility result comes from running `./build_legacy.sh` on OS X 10.9.5 /
Intel with Xcode 6.2 or the closest available legacy lane.
