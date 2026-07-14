#!/bin/bash

set -euo pipefail

ARCH="${1:-x86_64}"
BUILD_DIR="${2:-build-legacy/Vendor/libvpx}"
SDK_NAME="${3:-macosx}"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE_DIR="$ROOT_DIR/Vendor/libvpx"
OBJECT_DIR="$BUILD_DIR/Objects"
OUTPUT_LIBRARY="$BUILD_DIR/libvpxwebmdecoder.a"

if [ ! -x "$SOURCE_DIR/configure" ] || [ ! -f "$SOURCE_DIR/vpx/vpx_decoder.h" ]; then
    echo "Vendored libvpx sources are missing: $SOURCE_DIR"
    exit 1
fi
if [ ! -f "$SOURCE_DIR/third_party/libwebm/mkvparser/mkvparser.cc" ] || [ ! -f "$SOURCE_DIR/third_party/libwebm/mkvparser/mkvreader.cc" ]; then
    echo "Vendored libwebm parser sources are missing in: $SOURCE_DIR/third_party/libwebm"
    exit 1
fi

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR" "$OBJECT_DIR"

CLANG="$(xcrun --sdk "$SDK_NAME" --find clang)"
CLANGXX="$(xcrun --sdk "$SDK_NAME" --find clang++)"
SDK_PATH="$(xcrun --sdk "$SDK_NAME" --show-sdk-path)"
BASE_CFLAGS="-arch $ARCH -isysroot $SDK_PATH -mmacosx-version-min=10.9 -Os -DNDEBUG"
BASE_CXXFLAGS="$BASE_CFLAGS -std=c++11 -stdlib=libc++"
BASE_LDFLAGS="-arch $ARCH -isysroot $SDK_PATH -mmacosx-version-min=10.9"

pushd "$BUILD_DIR" >/dev/null
CC="$CLANG" \
CXX="$CLANGXX" \
CFLAGS="$BASE_CFLAGS" \
CXXFLAGS="$BASE_CXXFLAGS" \
LDFLAGS="$BASE_LDFLAGS" \
"$SOURCE_DIR/configure" \
    --target=generic-gnu \
    --disable-examples \
    --disable-docs \
    --disable-unit-tests \
    --disable-tools \
    --disable-vp8 \
    --disable-vp9-encoder \
    --enable-vp9-decoder \
    --enable-webm-io \
    --disable-shared \
    --enable-static \
    --disable-runtime-cpu-detect \
    --extra-cflags="$BASE_CFLAGS" \
    --extra-cxxflags="$BASE_CXXFLAGS"
make -j1
popd >/dev/null

if [ ! -f "$BUILD_DIR/libvpx.a" ]; then
    echo "libvpx static library was not produced: $BUILD_DIR/libvpx.a"
    exit 1
fi

WEBM_FLAGS=(
    -arch "$ARCH"
    -isysroot "$SDK_PATH"
    -mmacosx-version-min=10.9
    -std=c++11
    -stdlib=libc++
    -Os
    -DNDEBUG
    -I"$SOURCE_DIR/third_party/libwebm"
)

"$CLANGXX" "${WEBM_FLAGS[@]}" -c "$SOURCE_DIR/third_party/libwebm/mkvparser/mkvparser.cc" -o "$OBJECT_DIR/mkvparser.o"
"$CLANGXX" "${WEBM_FLAGS[@]}" -c "$SOURCE_DIR/third_party/libwebm/mkvparser/mkvreader.cc" -o "$OBJECT_DIR/mkvreader.o"

/usr/bin/libtool -static -o "$OUTPUT_LIBRARY" "$BUILD_DIR/libvpx.a" "$OBJECT_DIR/mkvparser.o" "$OBJECT_DIR/mkvreader.o"

if [ ! -f "$OUTPUT_LIBRARY" ]; then
    echo "VP9/WebM decoder library was not produced: $OUTPUT_LIBRARY"
    exit 1
fi

echo "Built VP9/WebM decoder: $OUTPUT_LIBRARY"
