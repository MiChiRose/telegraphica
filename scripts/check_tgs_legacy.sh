#!/bin/bash

set -euo pipefail

ARCH="${1:-x86_64}"
BUILD_DIR="${2:-build-legacy/Vendor/rlottie}"
SDK_NAME="${3:-macosx}"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RLOTTIE_LIBRARY="$BUILD_DIR/librlottie.a"
FIXTURE_JSON="$ROOT_DIR/Tests/Fixtures/tgs-animation.json"
FIXTURE_TGS="$BUILD_DIR/tgs-animation.tgs"
CLANG="$(xcrun --sdk "$SDK_NAME" --find clang)"
SDK_PATH="$(xcrun --sdk "$SDK_NAME" --show-sdk-path)"

if [ ! -f "$RLOTTIE_LIBRARY" ]; then
    "$ROOT_DIR/scripts/build_rlottie_legacy.sh" "$ARCH" "$BUILD_DIR" "$SDK_NAME"
fi
if [ ! -f "$FIXTURE_JSON" ]; then
    echo "TGS fixture is missing: $FIXTURE_JSON"
    exit 1
fi

gzip -c "$FIXTURE_JSON" > "$FIXTURE_TGS"

"$CLANG" \
    -arch "$ARCH" \
    -isysroot "$SDK_PATH" \
    -mmacosx-version-min=10.9 \
    -I"$ROOT_DIR/Vendor/rlottie/inc" \
    "$ROOT_DIR/Tests/tgs_renderer_probe.c" \
    "$RLOTTIE_LIBRARY" \
    -lc++ \
    -o "$BUILD_DIR/tgs_renderer_probe"

"$BUILD_DIR/tgs_renderer_probe" "$FIXTURE_JSON"

"$CLANG" \
    -arch "$ARCH" \
    -isysroot "$SDK_PATH" \
    -mmacosx-version-min=10.9 \
    -fno-objc-arc \
    -I"$ROOT_DIR/Sources/Media" \
    -I"$ROOT_DIR/Vendor/rlottie/inc" \
    "$ROOT_DIR/Tests/tgs_view_probe.m" \
    "$ROOT_DIR/Sources/Media/TGTGSFileValidator.m" \
    "$ROOT_DIR/Sources/Media/TGTGSAnimationView.m" \
    "$ROOT_DIR/Sources/Media/TGInlineMediaPlaybackCoordinator.m" \
    "$RLOTTIE_LIBRARY" \
    -lc++ \
    -lz \
    -framework Cocoa \
    -framework AVFoundation \
    -framework CoreMedia \
    -o "$BUILD_DIR/tgs_view_probe"

"$BUILD_DIR/tgs_view_probe" "$FIXTURE_TGS" "$FIXTURE_JSON"
