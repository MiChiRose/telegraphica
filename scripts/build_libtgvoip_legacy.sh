#!/bin/bash
set -euo pipefail

if [ "$#" -lt 4 ]; then
    echo "Usage: $0 <libtgvoip-2.4.4-source> <arch> <build-dir> <sdk-name>"
    exit 2
fi

SOURCE_DIR="$1"
ARCH="$2"
BUILD_DIR="$3"
SDK_NAME="$4"

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE_DIR="$(cd "$SOURCE_DIR" && pwd)"
WORK_DIR="$ROOT_DIR/$BUILD_DIR/source"
OUTPUT_DIR="$ROOT_DIR/$BUILD_DIR/output"
OPUS_PREFIX="$ROOT_DIR/build-legacy/Vendor/opus/prefix"
PATCH_FILE="$ROOT_DIR/Vendor/patches/libtgvoip-2.4.4-mavericks.patch"
DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET:-10.8}"

if [ ! -f "$SOURCE_DIR/TgVoip.h" ] || [ ! -d "$SOURCE_DIR/libtgvoip_osx.xcodeproj" ]; then
    echo "The source directory is not a libtgvoip 2.4.4 checkout: $SOURCE_DIR"
    exit 1
fi
if [ ! -f "$OPUS_PREFIX/lib/libopus.a" ]; then
    echo "Build Opus first; missing $OPUS_PREFIX/lib/libopus.a"
    exit 1
fi

rm -rf "$WORK_DIR" "$OUTPUT_DIR"
mkdir -p "$WORK_DIR" "$OUTPUT_DIR"
ditto "$SOURCE_DIR" "$WORK_DIR"
(
    cd "$WORK_DIR"
    patch -p1 < "$PATCH_FILE"
)

SDK_PATH="$(xcrun --sdk "$SDK_NAME" --show-sdk-path)"
XCODEBUILD="$(xcrun -f xcodebuild)"

"$XCODEBUILD" \
    -project "$WORK_DIR/libtgvoip_osx.xcodeproj" \
    -target libtgvoip \
    -configuration Debug \
    -sdk "$SDK_NAME" \
    ARCHS="$ARCH" \
    VALID_ARCHS="$ARCH" \
    ONLY_ACTIVE_ARCH=YES \
    MACOSX_DEPLOYMENT_TARGET="$DEPLOYMENT_TARGET" \
    SDKROOT="$SDK_PATH" \
    CLANG_CXX_LANGUAGE_STANDARD="gnu++11" \
    GCC_PREPROCESSOR_DEFINITIONS="\$(inherited) TGVOIP_USE_CUSTOM_CRYPTO TARGET_OSX=1" \
    EXCLUDED_SOURCE_FILE_NAMES="TGVVideoRenderer.mm TGVVideoSource.mm VideoToolboxEncoderSource.mm SampleBufferDisplayLayerRenderer.mm" \
    HEADER_SEARCH_PATHS="$WORK_DIR $WORK_DIR/webrtc_dsp $OPUS_PREFIX/include $OPUS_PREFIX/include/opus" \
    LIBRARY_SEARCH_PATHS="$OPUS_PREFIX/lib" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGN_IDENTITY= \
    build

FRAMEWORK_BINARY="$WORK_DIR/build/Debug/libtgvoip.framework/Versions/A/libtgvoip"
if [ ! -f "$FRAMEWORK_BINARY" ]; then
    echo "libtgvoip framework binary was not produced."
    exit 1
fi

ditto "$FRAMEWORK_BINARY" "$OUTPUT_DIR/libtgvoip.a"
ditto "$WORK_DIR/TgVoip.h" "$OUTPUT_DIR/TgVoip.h"

if ! lipo -info "$OUTPUT_DIR/libtgvoip.a" 2>/dev/null | grep -q "$ARCH"; then
    echo "libtgvoip archive does not contain $ARCH."
    file "$OUTPUT_DIR/libtgvoip.a"
    lipo -info "$OUTPUT_DIR/libtgvoip.a" 2>/dev/null || true
    exit 1
fi

echo "Created Mavericks-compatible libtgvoip: $OUTPUT_DIR/libtgvoip.a"
