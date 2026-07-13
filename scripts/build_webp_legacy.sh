#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE_DIR="$ROOT_DIR/Vendor/libwebp"
ARCH="${1:-x86_64}"
OUTPUT_DIR="${2:-$ROOT_DIR/build-webp-legacy}"
OBJECT_DIR="$OUTPUT_DIR/objects"
LIBRARY_PATH="$OUTPUT_DIR/libwebpdecoder.a"
DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET:-10.9}"

CC_BIN="${CC:-}"
if [ -z "$CC_BIN" ]; then
    CC_BIN="$(xcrun -f clang 2>/dev/null || command -v clang || command -v cc || true)"
fi
AR_BIN="${AR:-}"
if [ -z "$AR_BIN" ]; then
    AR_BIN="$(xcrun -f ar 2>/dev/null || command -v ar || true)"
fi
RANLIB_BIN="${RANLIB:-}"
if [ -z "$RANLIB_BIN" ]; then
    RANLIB_BIN="$(xcrun -f ranlib 2>/dev/null || command -v ranlib || true)"
fi
SDK_PATH="${SDKROOT:-}"
if [ -z "$SDK_PATH" ]; then
    SDK_PATH="$(xcrun --show-sdk-path 2>/dev/null || true)"
fi

if [ -z "$CC_BIN" ] || [ -z "$AR_BIN" ] || [ -z "$RANLIB_BIN" ]; then
    echo "clang, ar, and ranlib are required to build the WebP decoder."
    exit 1
fi
if [ ! -f "$SOURCE_DIR/COPYING" ] || [ ! -f "$SOURCE_DIR/PATENTS" ]; then
    echo "Vendored libwebp sources are incomplete: $SOURCE_DIR"
    exit 1
fi

SOURCES=(
    src/dec/alpha_dec.c
    src/dec/buffer_dec.c
    src/dec/frame_dec.c
    src/dec/idec_dec.c
    src/dec/io_dec.c
    src/dec/quant_dec.c
    src/dec/tree_dec.c
    src/dec/vp8_dec.c
    src/dec/vp8l_dec.c
    src/dec/webp_dec.c
    src/dsp/alpha_processing.c
    src/dsp/cpu.c
    src/dsp/dec.c
    src/dsp/dec_clip_tables.c
    src/dsp/filters.c
    src/dsp/lossless.c
    src/dsp/rescaler.c
    src/dsp/upsampling.c
    src/dsp/yuv.c
    src/utils/bit_reader_utils.c
    src/utils/color_cache_utils.c
    src/utils/filters_utils.c
    src/utils/huffman_utils.c
    src/utils/palette.c
    src/utils/quant_levels_dec_utils.c
    src/utils/random_utils.c
    src/utils/rescaler_utils.c
    src/utils/thread_utils.c
    src/utils/utils.c
)

rm -rf "$OUTPUT_DIR"
mkdir -p "$OBJECT_DIR"

OBJECTS=()
for relative_source in "${SOURCES[@]}"; do
    source_path="$SOURCE_DIR/$relative_source"
    object_name="$(echo "$relative_source" | tr '/.' '__').o"
    object_path="$OBJECT_DIR/$object_name"
    if [ ! -f "$source_path" ]; then
        echo "Missing vendored libwebp source: $source_path"
        exit 1
    fi
    COMPILE_FLAGS=(
        -arch "$ARCH"
        -mmacosx-version-min="$DEPLOYMENT_TARGET"
        -std=c99
        -O2
        -DNDEBUG
        -DHAVE_CONFIG_H
        -fvisibility=hidden
        -I"$SOURCE_DIR"
        -I"$SOURCE_DIR/src"
    )
    if [ -n "$SDK_PATH" ]; then
        COMPILE_FLAGS+=("-isysroot" "$SDK_PATH")
    fi
    "$CC_BIN" \
        "${COMPILE_FLAGS[@]}" \
        -c "$source_path" \
        -o "$object_path"
    OBJECTS+=("$object_path")
done

"$AR_BIN" rcs "$LIBRARY_PATH" "${OBJECTS[@]}"
"$RANLIB_BIN" "$LIBRARY_PATH"

echo "Created WebP decoder library: $LIBRARY_PATH"
