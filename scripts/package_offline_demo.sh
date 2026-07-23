#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

SOURCE_APP="${1:-build-legacy/Release/Telegraphica.app}"
DIST_DIR="${TELEGRAPHICA_DIST_DIR:-$PWD/dist}"
STAGE_ROOT="$PWD/build-legacy/OfflineDemoPackage"
DEMO_APP="$STAGE_ROOT/Telegraphica Offline Demo.app"

if [ ! -d "$SOURCE_APP" ]; then
    echo "Source app was not found: $SOURCE_APP"
    echo "Build Telegraphica first, then run this script again."
    exit 1
fi

SOURCE_INFO="$SOURCE_APP/Contents/Info.plist"
if [ ! -f "$SOURCE_INFO" ]; then
    echo "Source app is missing Contents/Info.plist."
    exit 1
fi

APP_VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$SOURCE_INFO" 2>/dev/null || true)"
if [ -z "$APP_VERSION" ]; then
    APP_VERSION="unknown"
fi

rm -rf "$STAGE_ROOT"
mkdir -p "$STAGE_ROOT" "$DIST_DIR"
ditto "$SOURCE_APP" "$DEMO_APP"

DEMO_INFO="$DEMO_APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.michirose.Telegraphica.OfflineDemo" "$DEMO_INFO"
/usr/libexec/PlistBuddy -c "Set :CFBundleName Telegraphica Offline Demo" "$DEMO_INFO"
/usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string Telegraphica Offline Demo" "$DEMO_INFO" 2>/dev/null || \
    /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName Telegraphica Offline Demo" "$DEMO_INFO"
/usr/libexec/PlistBuddy -c "Add :TelegraphicaDemoMode bool true" "$DEMO_INFO" 2>/dev/null || \
    /usr/libexec/PlistBuddy -c "Set :TelegraphicaDemoMode true" "$DEMO_INFO"

rm -f "$DEMO_APP/Contents/Frameworks/libtdjson.dylib"
rm -f "$DEMO_APP/Contents/Resources/TelegraphicaTDLibDefaults.plist"
rm -f "$DEMO_APP/Contents/Resources/tdlib-config.plist"

if codesign -dv "$DEMO_APP" >/dev/null 2>&1; then
    codesign --remove-signature "$DEMO_APP" >/dev/null 2>&1 || true
fi

DEMO_ZIP="$DIST_DIR/Telegraphica-Offline-Demo-v${APP_VERSION}-macos10.9-x86_64.app.zip"
rm -f "$DEMO_ZIP"
ditto -c -k --norsrc --keepParent "$DEMO_APP" "$DEMO_ZIP"

echo "Offline demo app: $DEMO_APP"
echo "Offline demo archive: $DEMO_ZIP"
