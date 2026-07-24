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
DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET:-10.8}"

if [ ! -d "$SOURCE_DIR/src" ] || [ ! -f "$SOURCE_DIR/inc/rlottie_capi.h" ]; then
    echo "Vendored rlottie sources are missing: $SOURCE_DIR"
    exit 1
fi

if grep -E -q 'const[[:space:]]+std::string[[:space:]]*&[[:space:]]*[A-Za-z_][A-Za-z_0-9]*[[:space:]]*=[[:space:]]*""' "$SOURCE_DIR/inc/rlottie.h"; then
    echo "rlottie contains an empty-string reference default that AppleClang 6.0 cannot parse."
    exit 1
fi

if grep -E -q 'Animation::loadFromFile\(path\)|Animation::loadFromData\(data,[[:space:]]*key,[[:space:]]*resourcePath\)|setValue<[^>]+>\(keypath' "$SOURCE_DIR/src/binding/c/lottieanimation_capi.cpp"; then
    echo "rlottie C API contains implicit C-string conversions that Mavericks libc++ cannot compile."
    exit 1
fi

for required_header in cstddef cstdint functional future memory string tuple type_traits vector; do
    if ! grep -F -q "#include <$required_header>" "$SOURCE_DIR/inc/rlottie.h"; then
        echo "rlottie public header is missing <$required_header>; Xcode 6 libc++ cannot rely on transitive includes."
        exit 1
    fi
done

rm -rf "$BUILD_DIR"
mkdir -p "$OBJECT_DIR" "$CONFIG_DIR"
printf '%s\n' '/* Telegraphica legacy rlottie configuration. */' > "$CONFIG_DIR/config.h"

CLANGXX="$(xcrun --sdk "$SDK_NAME" --find clang++)"
SDK_PATH="${SDKROOT:-$(xcrun --sdk "$SDK_NAME" --show-sdk-path)}"

COMMON_FLAGS=(
    -arch "$ARCH"
    -isysroot "$SDK_PATH"
    -mmacosx-version-min="$DEPLOYMENT_TARGET"
    -std=c++11
    -stdlib=libc++
    -Os
    -DNDEBUG
    -DRLOTTIE_BUILD
    -fno-exceptions
    -fno-rtti
    -fno-unwind-tables
    -fno-asynchronous-unwind-tables
    -Wno-unused-parameter
    -include "$SOURCE_DIR/src/telegraphica/cxx11_compat.h"
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
