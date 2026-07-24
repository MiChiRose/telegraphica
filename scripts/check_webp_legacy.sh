#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ARCH="${WEBP_TEST_ARCH:-$(uname -m)}"
BUILD_DIR="${TMPDIR:-/tmp}/telegraphica-webp-check"
CC_BIN="$(xcrun -f clang 2>/dev/null || command -v clang || command -v cc || true)"
SDK_PATH="${SDKROOT:-$(xcrun --show-sdk-path 2>/dev/null || true)}"
DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET:-10.8}"

if [ -z "$CC_BIN" ]; then
    echo "clang or cc is required for the WebP decoder check."
    exit 1
fi

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
"$ROOT_DIR/scripts/build_webp_legacy.sh" "$ARCH" "$BUILD_DIR/library"

COMPILE_FLAGS=(
    -arch "$ARCH"
    -mmacosx-version-min="$DEPLOYMENT_TARGET"
    -I"$ROOT_DIR/Vendor/libwebp/src"
)
if [ -n "$SDK_PATH" ]; then
    COMPILE_FLAGS+=("-isysroot" "$SDK_PATH")
fi

"$CC_BIN" \
    "${COMPILE_FLAGS[@]}" \
    "$ROOT_DIR/Tests/webp_decoder_probe.c" \
    "$BUILD_DIR/library/libwebpdecoder.a" \
    -o "$BUILD_DIR/webp_decoder_probe"

"$BUILD_DIR/webp_decoder_probe" "$ROOT_DIR/Tests/Fixtures/libwebp-test.webp"

"$CC_BIN" \
    "${COMPILE_FLAGS[@]}" \
    -fno-objc-arc \
    -I"$ROOT_DIR/Sources/Media" \
    "$ROOT_DIR/Tests/webp_nsimage_probe.m" \
    "$ROOT_DIR/Sources/Media/TGWebPDecoder.m" \
    "$ROOT_DIR/Sources/Media/TGMediaImageLoader.m" \
    "$BUILD_DIR/library/libwebpdecoder.a" \
    -framework Cocoa \
    -o "$BUILD_DIR/webp_nsimage_probe"

"$BUILD_DIR/webp_nsimage_probe" "$ROOT_DIR/Tests/Fixtures/libwebp-test.webp"
rm -rf "$BUILD_DIR"
