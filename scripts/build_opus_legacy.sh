#!/bin/bash
set -euo pipefail

if [ "$#" -lt 3 ]; then
    echo "Usage: $0 <arch> <build-dir> <sdk-name>"
    exit 2
fi

ARCH="$1"
BUILD_DIR="$2"
SDK_NAME="$3"

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VENDOR_DIR="$ROOT_DIR/Vendor"
PREFIX="$ROOT_DIR/$BUILD_DIR/prefix"
HELPER_DIR="$ROOT_DIR/$BUILD_DIR/bin"
LOG_DIR="$ROOT_DIR/$BUILD_DIR/logs"
DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET:-10.8}"

SDK_PATH="${SDKROOT:-$(xcrun --sdk "$SDK_NAME" --show-sdk-path 2>/dev/null || true)}"
if [ -z "$SDK_PATH" ]; then
    echo "Could not resolve SDK path for $SDK_NAME"
    exit 1
fi

mkdir -p "$PREFIX" "$HELPER_DIR" "$LOG_DIR"

COMMON_CFLAGS="-arch $ARCH -isysroot $SDK_PATH -mmacosx-version-min=$DEPLOYMENT_TARGET -O2"
COMMON_LDFLAGS="-arch $ARCH -isysroot $SDK_PATH -mmacosx-version-min=$DEPLOYMENT_TARGET"
HOST="$ARCH-apple-darwin"

build_configure_project() {
    local source_dir="$1"
    local build_subdir="$2"
    shift 2
    local build_path="$ROOT_DIR/$BUILD_DIR/$build_subdir"
    rm -rf "$build_path"
    mkdir -p "$build_path"
    (
        cd "$build_path"
        MAKE=/usr/bin/make \
        CFLAGS="$COMMON_CFLAGS" \
        LDFLAGS="$COMMON_LDFLAGS" \
        PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig" \
        DEPS_CFLAGS="${DEPS_CFLAGS:-}" \
        DEPS_LIBS="${DEPS_LIBS:-}" \
        "$source_dir/configure" \
            --host="$HOST" \
            --prefix="$PREFIX" \
            --disable-shared \
            --enable-static \
            "$@" > "$LOG_DIR/$build_subdir-configure.log" 2>&1
        MAKE=/usr/bin/make /usr/bin/make -j2 MAKE=/usr/bin/make > "$LOG_DIR/$build_subdir-make.log" 2>&1
        MAKE=/usr/bin/make /usr/bin/make install MAKE=/usr/bin/make > "$LOG_DIR/$build_subdir-install.log" 2>&1
    )
}

build_configure_project "$VENDOR_DIR/libogg" "libogg" --disable-doc
build_configure_project "$VENDOR_DIR/opus" "opus" --disable-doc --disable-extra-programs
DEPS_CFLAGS="-I$PREFIX/include -I$PREFIX/include/opus" \
DEPS_LIBS="-L$PREFIX/lib -lopus -logg" \
build_configure_project "$VENDOR_DIR/opusfile" "opusfile" --disable-doc --disable-examples --disable-http

cc $COMMON_CFLAGS \
    -I"$PREFIX/include" \
    -I"$PREFIX/include/opus" \
    "$ROOT_DIR/Tools/tgopusdec.c" \
    "$PREFIX/lib/libopusfile.a" \
    "$PREFIX/lib/libopus.a" \
    "$PREFIX/lib/libogg.a" \
    -lm \
    -o "$HELPER_DIR/tgopusdec"

file "$HELPER_DIR/tgopusdec"
echo "Created Opus decoder helper: $HELPER_DIR/tgopusdec"
