#!/bin/bash

set -euo pipefail

ARCH="${1:-x86_64}"
BUILD_DIR="${2:-build-legacy/Tests/media-item-support}"
SDK_NAME="${3:-macosx}"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CLANG="$(xcrun --sdk "$SDK_NAME" --find clang)"
SDK_PATH="${SDKROOT:-$(xcrun --sdk "$SDK_NAME" --show-sdk-path)}"
DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET:-10.8}"

mkdir -p "$BUILD_DIR"
"$CLANG" \
    -arch "$ARCH" \
    -isysroot "$SDK_PATH" \
    -mmacosx-version-min="$DEPLOYMENT_TARGET" \
    -fno-objc-arc \
    -I"$ROOT_DIR/Sources/Media" \
    "$ROOT_DIR/Tests/media_item_support_probe.m" \
    "$ROOT_DIR/Sources/Media/TGMediaItemSupport.m" \
    -framework Cocoa \
    -o "$BUILD_DIR/media_item_support_probe"

"$BUILD_DIR/media_item_support_probe"
echo "Media preview gate passed: stickers are not previewable."
