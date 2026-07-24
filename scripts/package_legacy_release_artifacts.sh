#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

DIST_DIR="${TELEGRAPHICA_DIST_DIR:-$PWD/dist}"
APP_PATH="build-legacy/Release/Telegraphica.app"
APP_NAME="Telegraphica.app"
ARCH="x86_64"
DEPLOYMENT_TARGET="${TELEGRAPHICA_DEPLOYMENT_TARGET:-${MACOSX_DEPLOYMENT_TARGET:-10.8}}"
COMPATIBILITY_TAG="${TELEGRAPHICA_COMPATIBILITY_TAG:-macos10.8-10.13}"

usage() {
    cat <<USAGE
Usage: $0 --tdjson /path/to/modern/libtdjson.dylib \
          --mountain-lion-tdjson /path/to/10.8/libtdjson.dylib

Builds Telegraphica with bundled TDLib on the legacy Mac, then creates release
artifacts in dist/:

  - Telegraphica-v<VERSION>-${COMPATIBILITY_TAG}-x86_64.dmg
  - Telegraphica-v<VERSION>-${COMPATIBILITY_TAG}-x86_64.app.zip
  - matching .sha256 files

The script refuses to package a public installer unless the OS X 10.9+ and
OS X 10.8 TDLib runtimes are both bundled inside Telegraphica.app.
USAGE
}

TDJSON_PATH="${TELEGRAPHICA_TDJSON_PATH:-}"
TDJSON_MOUNTAIN_LION_PATH="${TELEGRAPHICA_TDJSON_MOUNTAIN_LION_PATH:-}"
while [ "$#" -gt 0 ]; do
    case "$1" in
        --tdjson)
            shift
            if [ "$#" -eq 0 ]; then
                echo "--tdjson requires a path."
                exit 1
            fi
            TDJSON_PATH="$1"
            ;;
        --mountain-lion-tdjson)
            shift
            if [ "$#" -eq 0 ]; then
                echo "--mountain-lion-tdjson requires a path."
                exit 1
            fi
            TDJSON_MOUNTAIN_LION_PATH="$1"
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
    shift
done

find_tdjson() {
    local candidate
    for candidate in \
        "$PWD/build-tdlib-master-legacy/stage/Frameworks/libtdjson.dylib" \
        "$PWD/build-tdlib-legacy/stage/Frameworks/libtdjson.dylib" \
        "$HOME/Desktop/Telegraphica-current/build-tdlib-master-legacy/stage/Frameworks/libtdjson.dylib" \
        "$HOME/Desktop/Telegraphica-current/build-tdlib-legacy/stage/Frameworks/libtdjson.dylib" \
        "$HOME/Desktop/Telegraphica-10.8-current/build-tdlib-master-legacy/stage/Frameworks/libtdjson.dylib" \
        "$HOME/Desktop/Telegraphica-10.8-current/build-tdlib-legacy/stage/Frameworks/libtdjson.dylib"
    do
        if [ -f "$candidate" ] &&
            TELEGRAPHICA_REQUIRE_PORTABLE_TDJSON=1 scripts/check_tdjson_legacy.sh "$candidate" >/dev/null 2>&1; then
            echo "$candidate"
            return 0
        fi
    done
}

if [ -z "$TDJSON_PATH" ] || [ ! -f "$TDJSON_PATH" ]; then
    echo "The modern OS X 10.9+ libtdjson.dylib was not found."
    echo "Pass it explicitly:"
    echo "  $0 --tdjson /path/to/libtdjson.dylib"
    exit 1
fi

if [ -z "$TDJSON_MOUNTAIN_LION_PATH" ]; then
    TDJSON_MOUNTAIN_LION_PATH="$(find_tdjson)"
fi

if [ -z "$TDJSON_MOUNTAIN_LION_PATH" ] || [ ! -f "$TDJSON_MOUNTAIN_LION_PATH" ]; then
    echo "The OS X 10.8 libtdjson.dylib was not found."
    echo "Pass it explicitly:"
    echo "  $0 --tdjson /path/to/modern/libtdjson.dylib --mountain-lion-tdjson /path/to/10.8/libtdjson.dylib"
    exit 1
fi

if [ -n "${PYTHON:-}" ]; then
    PYTHON_BIN="$PYTHON"
elif command -v python3 >/dev/null 2>&1; then
    PYTHON_BIN="$(command -v python3)"
elif command -v python >/dev/null 2>&1; then
    PYTHON_BIN="$(command -v python)"
else
    PYTHON_BIN=""
fi

if [ -n "$PYTHON_BIN" ]; then
    "$PYTHON_BIN" scripts/check_legacy_compat.py
fi

MACOSX_DEPLOYMENT_TARGET=10.9 scripts/check_tdjson_legacy.sh "$TDJSON_PATH"
MACOSX_DEPLOYMENT_TARGET=10.8 scripts/check_tdjson_legacy.sh "$TDJSON_MOUNTAIN_LION_PATH"

echo "Building Telegraphica with bundled TDLib runtimes:"
echo "  OS X 10.9+: $TDJSON_PATH"
echo "  OS X 10.8:  $TDJSON_MOUNTAIN_LION_PATH"
BUILD_DIST_DIR="$(mktemp -d /tmp/telegraphica-release-build.XXXXXX)"
cleanup_build_dist() {
    rm -rf "$BUILD_DIST_DIR"
}
trap cleanup_build_dist EXIT
TELEGRAPHICA_DIST_DIR="$BUILD_DIST_DIR" \
TELEGRAPHICA_TDJSON_PATH="$TDJSON_PATH" \
TELEGRAPHICA_TDJSON_MOUNTAIN_LION_PATH="$TDJSON_MOUNTAIN_LION_PATH" \
TELEGRAPHICA_REMOTE_TDLIB_CONFIG_URL="${TELEGRAPHICA_REMOTE_TDLIB_CONFIG_URL:-}" \
./build_legacy.sh

BUNDLED_TDJSON="$APP_PATH/Contents/Frameworks/libtdjson.dylib"
BUNDLED_TDJSON_MOUNTAIN_LION="$APP_PATH/Contents/Frameworks/libtdjson-mountain-lion.dylib"
if [ ! -f "$BUNDLED_TDJSON" ] || [ ! -f "$BUNDLED_TDJSON_MOUNTAIN_LION" ]; then
    echo "Build finished, but one or both bundled TDLib runtimes are missing:"
    echo "  $BUNDLED_TDJSON"
    echo "  $BUNDLED_TDJSON_MOUNTAIN_LION"
    exit 1
fi

MACOSX_DEPLOYMENT_TARGET=10.9 TELEGRAPHICA_REQUIRE_PORTABLE_TDJSON=1 scripts/check_tdjson_legacy.sh "$BUNDLED_TDJSON"
MACOSX_DEPLOYMENT_TARGET=10.8 TELEGRAPHICA_REQUIRE_PORTABLE_TDJSON=1 scripts/check_tdjson_legacy.sh "$BUNDLED_TDJSON_MOUNTAIN_LION"
TELEGRAPHICA_BUNDLE_MANIFEST_PATH="$BUILD_DIST_DIR/TelegraphicaLegacyBinaryManifest.tsv" \
scripts/check_release_bundle_legacy.sh "$APP_PATH" "$DEPLOYMENT_TARGET"

BUNDLED_CONFIG="$APP_PATH/Contents/Resources/TelegraphicaTDLibDefaults.plist"
RUNTIME_CONFIG_MARKER="$APP_PATH/Contents/Resources/TelegraphicaTDLibRuntimeDefaults.plist"
INFO_PLIST="$APP_PATH/Contents/Info.plist"
if [ -f "$BUNDLED_CONFIG" ]; then
    echo "Refusing to create release artifacts with plaintext TDLib app credentials in Resources."
    echo "Unexpected file: $BUNDLED_CONFIG"
    exit 1
fi
HAS_RUNTIME_CREDENTIALS="$(/usr/libexec/PlistBuddy -c "Print :has_runtime_credentials" "$RUNTIME_CONFIG_MARKER" 2>/dev/null || true)"
REMOTE_CONFIG_URL="$(/usr/libexec/PlistBuddy -c "Print :TelegraphicaRemoteTDLibConfigURL" "$INFO_PLIST" 2>/dev/null || true)"
if [ "$HAS_RUNTIME_CREDENTIALS" != "true" ] && ! echo "$REMOTE_CONFIG_URL" | grep -E -q '^https://'; then
    echo "Refusing to create release artifacts without a Telegram connection bootstrap."
    echo "Rebuild with either:"
    echo "  TELEGRAPHICA_BUNDLED_TDLIB_CONFIG_PATH=/private/path/to/tdlib-config.plist"
    echo "or:"
    echo "  TELEGRAPHICA_REMOTE_TDLIB_CONFIG_URL=https://example.workers.dev/v1/tdlib-config"
    exit 1
fi

APP_VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$INFO_PLIST" 2>/dev/null || true)"
if [ -z "$APP_VERSION" ]; then
    APP_VERSION="0.0.0"
fi

mkdir -p "$DIST_DIR"

scripts/package_release_installer.sh "$APP_PATH"

DMG_SRC="$DIST_DIR/Telegraphica-v${APP_VERSION}-installer.dmg"
DMG_FINAL="$DIST_DIR/Telegraphica-v${APP_VERSION}-${COMPATIBILITY_TAG}-${ARCH}.dmg"
APP_ZIP="$DIST_DIR/Telegraphica-v${APP_VERSION}-${COMPATIBILITY_TAG}-${ARCH}.app.zip"

if [ ! -f "$DMG_SRC" ]; then
    echo "Expected DMG was not created:"
    echo "$DMG_SRC"
    exit 1
fi

mv -f "$DMG_SRC" "$DMG_FINAL"
rm -f "$APP_ZIP"
ditto -c -k --norsrc --keepParent "$APP_PATH" "$APP_ZIP"

for artifact in "$DMG_FINAL" "$APP_ZIP"; do
    rm -f "$artifact.sha256"
    (
        cd "$(dirname "$artifact")"
        shasum -a 256 "$(basename "$artifact")"
    ) > "$artifact.sha256"
done

echo
echo "Created release artifacts:"
echo "$DMG_FINAL"
echo "$APP_ZIP"
echo "$DMG_FINAL.sha256"
echo "$APP_ZIP.sha256"
