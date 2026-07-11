#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

APP_PATH="${1:-build-legacy/Release/Telegraphica.app}"
DIST_DIR="${TELEGRAPHICA_DIST_DIR:-$PWD/dist}"

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

cat > "$STAGE_DIR/README_FIRST.txt" <<'NOTE'
Telegraphica alpha installer

Drag Telegraphica.app to Applications.

Telegraphica is an unofficial legacy Telegram client. It needs a compatible
TDLib JSON library (libtdjson.dylib). If this app was built without bundled
TDLib, install or build libtdjson.dylib separately, then rebuild Telegraphica
with TELEGRAPHICA_TDJSON_PATH=/path/to/libtdjson.dylib ./build_legacy.sh.

Do not put Telegram api_id, api_hash, login codes, 2FA passwords, TDLib
databases, or session files inside this DMG.
NOTE

rm -f "$DMG_PATH"
hdiutil create \
    -volname "Telegraphica ${APP_VERSION}" \
    -srcfolder "$STAGE_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

echo "Created $DMG_NAME at $DMG_PATH"
