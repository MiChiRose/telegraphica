#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

APP_PATH="${1:-build-legacy/Release/Telegraphica.app}"
DIST_DIR="${TELEGRAPHICA_DIST_DIR:-$PWD/dist}"
ALLOW_TDLIBLESS_INSTALLER="${TELEGRAPHICA_ALLOW_TDLIBLESS_INSTALLER:-0}"

if [ ! -d "$APP_PATH" ]; then
    echo "Telegraphica.app was not found at: $APP_PATH"
    echo "Run ./build_legacy.sh first, optionally with TELEGRAPHICA_TDJSON_PATH."
    exit 1
fi

if ! command -v hdiutil >/dev/null 2>&1; then
    echo "hdiutil was not found; DMG packaging requires macOS."
    exit 1
fi

INFO_PLIST="$APP_PATH/Contents/Info.plist"
APP_VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$INFO_PLIST" 2>/dev/null || true)"
if [ -z "$APP_VERSION" ]; then
    APP_VERSION="0.0.0"
fi

TDJSON_BUNDLED_PATH="$APP_PATH/Contents/Frameworks/libtdjson.dylib"
if [ ! -f "$TDJSON_BUNDLED_PATH" ]; then
    if [ "$ALLOW_TDLIBLESS_INSTALLER" != "1" ]; then
        echo "Refusing to create a public installer without bundled TDLib:"
        echo "  $TDJSON_BUNDLED_PATH was not found."
        echo
        echo "Build Telegraphica first with:"
        echo "  TELEGRAPHICA_TDJSON_PATH=/path/to/libtdjson.dylib ./build_legacy.sh"
        echo
        echo "For a development-only DMG without TDLib, rerun with:"
        echo "  TELEGRAPHICA_ALLOW_TDLIBLESS_INSTALLER=1 ./scripts/package_release_installer.sh"
        exit 1
    fi
    TDLIB_NOTE="This development image does not include libtdjson.dylib. It can open only on machines that already provide a compatible TDLib JSON library."
else
    TDLIB_NOTE="This installer includes libtdjson.dylib inside Telegraphica.app/Contents/Frameworks."
fi

mkdir -p "$DIST_DIR"

DMG_NAME="Telegraphica-v${APP_VERSION}-installer.dmg"
DMG_PATH="$DIST_DIR/$DMG_NAME"
STAGE_DIR="$(mktemp -d /tmp/telegraphica-dmg.XXXXXX)"

cleanup() {
    rm -rf "$STAGE_DIR"
}
trap cleanup EXIT

ditto "$APP_PATH" "$STAGE_DIR/Telegraphica.app"
ln -s /Applications "$STAGE_DIR/Applications"

cat > "$STAGE_DIR/README_FIRST.txt" <<NOTE
Telegraphica alpha installer

Drag Telegraphica.app to Applications.

Telegraphica is an unofficial legacy Telegram client for OS X 10.9.5 Mavericks.

$TDLIB_NOTE

If the app reports that TDLib is unavailable, rebuild Telegraphica on the legacy
Mac with:

TELEGRAPHICA_TDJSON_PATH=/path/to/libtdjson.dylib ./build_legacy.sh
./scripts/package_release_installer.sh

Do not put Telegram api_id, api_hash, login codes, 2FA passwords, TDLib
databases, or session files inside this DMG.
NOTE

rm -f "$DMG_PATH"
hdiutil create \
    -volname "Telegraphica ${APP_VERSION}" \
    -srcfolder "$STAGE_DIR" \
    -ov \
    -format UDZO \
    -fs HFS+ \
    -layout SPUD \
    "$DMG_PATH"

echo "Created $DMG_NAME at $DMG_PATH"
