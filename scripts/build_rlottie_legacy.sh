#!/bin/bash

set -euo pipefail

ARCH="${1:-x86_64}"
BUILD_DIR="${2:-build-legacy/Vendor/rlottie}"
SDK_NAME="${3:-macosx}"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE_DIR="$ROOT_DIR/Vendor/rlottie"
OBJECT_DIR="$BUILD_DIR/Objects"
CONFIG_DIR="$BUILD_DIR/Generated"
OUTPUT_LIBRARY="$BUILD_DIR/librlottie.a"

if [ ! -d "$SOURCE_DIR/src" ] || [ ! -f "$SOURCE_DIR/inc/rlottie_capi.h" ]; then
    echo "Vendored rlottie sources are missing: $SOURCE_DIR"
    exit 1
fi

rm -rf "$BUILD_DIR"
mkdir -p "$OBJECT_DIR" "$CONFIG_DIR"
printf '%s\n' '/* Telegraphica legacy rlottie configuration. */' > "$CONFIG_DIR/config.h"

CLANGXX="$(xcrun --sdk "$SDK_NAME" --find clang++)"
SDK_PATH="$(xcrun --sdk "$SDK_NAME" --show-sdk-path)"

COMMON_FLAGS=(
    -arch "$ARCH"
    -isysroot "$SDK_PATH"
    -mmacosx-version-min=10.9
    -std=c++1y
    -stdlib=libc++
    -Os
    -DNDEBUG
    -DRLOTTIE_BUILD
    -fno-exceptions
    -fno-rtti
    -fno-unwind-tables
    -fno-asynchronous-unwind-tables
    -Wno-unused-parameter
    -I"$CONFIG_DIR"
    -I"$SOURCE_DIR/inc"
    -I"$SOURCE_DIR/src/vector"
    -I"$SOURCE_DIR/src/vector/freetype"
    -I"$SOURCE_DIR/src/vector/pixman"
    -I"$SOURCE_DIR/src/vector/stb"
    -I"$SOURCE_DIR/src/lottie"
    -I"$SOURCE_DIR/src/lottie/rapidjson"
    -I"$SOURCE_DIR/src/binding/c"
)

SOURCE_LIST="$BUILD_DIR/sources.txt"
find "$SOURCE_DIR/src" -type f -name '*.cpp' \
    ! -name 'vdrawhelper_neon.cpp' \
    ! -name 'stb_image.cpp' \
    ! -path "$SOURCE_DIR/src/wasm/*" \
    -print | LC_ALL=C sort > "$SOURCE_LIST"

while IFS= read -r SOURCE_FILE; do
    RELATIVE_PATH="${SOURCE_FILE#$SOURCE_DIR/}"
    OBJECT_NAME="$(printf '%s' "$RELATIVE_PATH" | tr '/.' '__').o"
    "$CLANGXX" "${COMMON_FLAGS[@]}" -c "$SOURCE_FILE" -o "$OBJECT_DIR/$OBJECT_NAME"
done < "$SOURCE_LIST"

/usr/bin/libtool -static -o "$OUTPUT_LIBRARY" "$OBJECT_DIR"/*.o

if [ ! -f "$OUTPUT_LIBRARY" ]; then
    echo "rlottie static library was not produced: $OUTPUT_LIBRARY"
    exit 1
fi

echo "Built rlottie: $OUTPUT_LIBRARY"
