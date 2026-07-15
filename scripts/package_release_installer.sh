#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

APP_PATH="${1:-build-legacy/Release/Telegraphica.app}"
DIST_DIR="${TELEGRAPHICA_DIST_DIR:-$PWD/dist}"
ALLOW_TDLIBLESS_INSTALLER="${TELEGRAPHICA_ALLOW_TDLIBLESS_INSTALLER:-0}"
PUBLIC_RELEASE="${TELEGRAPHICA_PUBLIC_RELEASE:-0}"

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
fi

BUNDLED_CONFIG_PATH="$APP_PATH/Contents/Resources/TelegraphicaTDLibDefaults.plist"
RUNTIME_CONFIG_MARKER="$APP_PATH/Contents/Resources/TelegraphicaTDLibRuntimeDefaults.plist"
if [ -f "$BUNDLED_CONFIG_PATH" ]; then
    echo "Refusing to create an installer with plaintext TDLib app credentials in Resources."
    echo "Unexpected file: $BUNDLED_CONFIG_PATH"
    exit 1
fi
HAS_RUNTIME_CREDENTIALS="$(/usr/libexec/PlistBuddy -c "Print :has_runtime_credentials" "$RUNTIME_CONFIG_MARKER" 2>/dev/null || true)"
if [ "$PUBLIC_RELEASE" = "1" ]; then
    if [ "$HAS_RUNTIME_CREDENTIALS" = "true" ]; then
        echo "Refusing to create a public installer with bundled runtime Telegram credentials."
        exit 1
    fi
elif [ "$HAS_RUNTIME_CREDENTIALS" != "true" ]; then
    echo "Refusing to create an installer without a runtime Telegram connection configuration marker."
    exit 1
fi

mkdir -p "$DIST_DIR"

DMG_NAME="Telegraphica-v${APP_VERSION}-installer.dmg"
DMG_PATH="$DIST_DIR/$DMG_NAME"
STAGE_DIR="$(mktemp -d /tmp/telegraphica-dmg.XXXXXX)"
RW_DMG_PATH="$STAGE_DIR/Telegraphica-rw.dmg"
MOUNT_DIR=""
MOUNT_DEVICE=""
BACKGROUND_SOURCE="$PWD/scripts/assets/TelegraphicaInstallerBackground.png"
VOLUME_NAME="Telegraphica ${APP_VERSION}"
PUBLISH_TMP_PATH="$DIST_DIR/.Telegraphica-v${APP_VERSION}-installer.$$.dmg"
MOUNTED=0

cleanup() {
    if [ "$MOUNTED" = "1" ]; then
        if [ -z "$MOUNT_DEVICE" ]; then
            MOUNT_DEVICE="$(hdiutil info 2>/dev/null | awk -v image="$RW_DMG_PATH" '
                /^image-path[[:space:]]*:/ {
                    path = $0
                    sub(/^image-path[[:space:]]*:[[:space:]]*/, "", path)
                    matching = (path == image)
                    next
                }
                matching && /^\/dev\/disk/ && /Apple_HFS/ { print $1; exit }
            ')"
        fi
        if [ -n "$MOUNT_DEVICE" ]; then
            hdiutil detach "$MOUNT_DEVICE" -force >/dev/null 2>&1 || true
        elif [ -n "$MOUNT_DIR" ] && [ -d "$MOUNT_DIR" ]; then
            hdiutil detach "$MOUNT_DIR" -force >/dev/null 2>&1 || true
        fi
    fi
    rm -f "$PUBLISH_TMP_PATH"
    rm -rf "$STAGE_DIR"
}
trap cleanup EXIT

if [ ! -f "$BACKGROUND_SOURCE" ]; then
    echo "Installer background was not found:"
    echo "  $BACKGROUND_SOURCE"
    exit 1
fi

PAYLOAD_KB="$(du -sk "$APP_PATH" | awk '{print $1}')"
IMAGE_MB=$(( (PAYLOAD_KB + 1023) / 1024 + 32 ))

hdiutil create \
    -ov \
    -size "${IMAGE_MB}m" \
    -volname "$VOLUME_NAME" \
    -fs HFS+ \
    -layout SPUD \
    "$RW_DMG_PATH"

MOUNTED=1
ATTACH_OUTPUT="$(hdiutil attach \
    -readwrite \
    -noverify \
    -noautoopen \
    "$RW_DMG_PATH")"
echo "$ATTACH_OUTPUT"
MOUNT_DEVICE="$(printf '%s\n' "$ATTACH_OUTPUT" | awk '/Apple_HFS/ {print $1; exit}')"
MOUNT_DIR="$(printf '%s\n' "$ATTACH_OUTPUT" | awk '/Apple_HFS/ {sub(/^.*Apple_HFS[[:space:]]*/, ""); print; exit}')"
if [ -z "$MOUNT_DIR" ] || [ ! -d "$MOUNT_DIR" ]; then
    echo "Could not determine the mounted installer volume path."
    exit 1
fi

ditto "$APP_PATH" "$MOUNT_DIR/Telegraphica.app"
ln -s /Applications "$MOUNT_DIR/Applications"
mkdir -p "$MOUNT_DIR/.background"
ditto "$BACKGROUND_SOURCE" "$MOUNT_DIR/.background/TelegraphicaInstallerBackground.png"
chflags hidden "$MOUNT_DIR/.background" || true

LAYOUT_SCRIPT="$STAGE_DIR/layout.applescript"
cat > "$LAYOUT_SCRIPT" <<'APPLESCRIPT'
on run argv
    set volumeName to item 1 of argv
    using terms from application "Finder"
        tell application "Finder"
            set matchingDisks to every disk whose name is volumeName
            repeat with attemptNumber from 1 to 40
                if (count of matchingDisks) is greater than 0 then exit repeat
                delay 0.25
                set matchingDisks to every disk whose name is volumeName
            end repeat
            if (count of matchingDisks) is 0 then error "Finder could not find mounted disk " & volumeName
            if (count of matchingDisks) is greater than 1 then error "More than one Finder disk is named " & volumeName & ". Eject the older installer volume and try again."
            set targetDisk to item 1 of matchingDisks
            tell targetDisk
                open
                set current view of container window to icon view
                set toolbar visible of container window to false
                set statusbar visible of container window to false
                set bounds of container window to {100, 100, 700, 500}
                set viewOptions to icon view options of container window
                set arrangement of viewOptions to not arranged
                set icon size of viewOptions to 104
                set text size of viewOptions to 12
                set label position of viewOptions to bottom
                set shows item info of viewOptions to false
                set shows icon preview of viewOptions to false
                set background picture of viewOptions to file ".background:TelegraphicaInstallerBackground.png"
                set position of item "Telegraphica.app" of container window to {132, 205}
                set position of item "Applications" of container window to {468, 205}
                update without registering applications
                delay 2
                close
            end tell
        end tell
    end using terms from
end run
APPLESCRIPT

osascript "$LAYOUT_SCRIPT" "$VOLUME_NAME"
sync
sleep 2

hdiutil detach "$MOUNT_DIR"
MOUNTED=0
MOUNT_DEVICE=""
MOUNT_DIR=""

rm -f "$PUBLISH_TMP_PATH"
hdiutil convert "$RW_DMG_PATH" \
    -ov \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "$PUBLISH_TMP_PATH"

hdiutil verify "$PUBLISH_TMP_PATH"
mv -f "$PUBLISH_TMP_PATH" "$DMG_PATH"

echo "Created $DMG_NAME at $DMG_PATH"
