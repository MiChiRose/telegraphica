#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

TDLIB_VERSION="${TDLIB_VERSION:-v1.8.0}"
ARCH="${TELEGRAPHICA_ARCH:-x86_64}"
DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET:-10.9}"
BUILD_DIR="$ROOT_DIR/build-tdlib-legacy"
INSTALL_DIR=""
STAGE_DIR=""
SOURCE_PATH=""
ARCHIVE_PATH=""
OPENSSL_ROOT="${TDLIB_OPENSSL_ROOT:-}"
ZLIB_ROOT="${TDLIB_ZLIB_ROOT:-}"
CMAKE_BIN="${CMAKE:-cmake}"
GPERF_BIN="${GPERF:-gperf}"
JOBS=""
CLEAN=0
ALLOW_UNKNOWN_TAG=0

usage() {
    cat <<EOF
Usage:
  $0 --source /path/to/td [options]
  $0 --archive /path/to/td-${TDLIB_VERSION}.tar.gz [options]

Options:
  --build-dir PATH        default: $BUILD_DIR
  --install-dir PATH      default: BUILD_DIR/install
  --stage-dir PATH        default: BUILD_DIR/stage
  --openssl-root PATH     OpenSSL prefix with include/ and lib/
  --zlib-root PATH        Optional zlib prefix with include/ and lib/
  --cmake PATH            default: cmake
  --gperf PATH            default: gperf
  --jobs N                default: host CPU count, fallback 2
  --clean                 remove BUILD_DIR before configuring
  --allow-unknown-tag     allow sources that cannot prove ${TDLIB_VERSION}
  -h, --help              show this help

The script builds TDLib tdjson for OS X ${DEPLOYMENT_TARGET} / ${ARCH}, stages
libtdjson.dylib into STAGE_DIR/Frameworks, and validates it for Telegraphica.
EOF
}

fail() {
    echo "$1"
    exit 1
}

abs_path() {
    local path="$1"
    local dir=""
    local base=""
    if [ -d "$path" ]; then
        cd "$path" && pwd
    else
        dir="$(dirname "$path")"
        base="$(basename "$path")"
        cd "$dir" && printf "%s/%s\n" "$(pwd)" "$base"
    fi
}

require_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        fail "$1 was not found."
    fi
}

require_option_value() {
    if [ "$#" -lt 2 ] || [ -z "$2" ]; then
        fail "$1 requires a value."
    fi
    case "$2" in
        --*)
            fail "$1 requires a value, got option $2."
            ;;
    esac
}

default_jobs() {
    local count=""
    count="$(sysctl -n hw.ncpu 2>/dev/null || true)"
    if [ -z "$count" ]; then
        count="2"
    fi
    echo "$count"
}

extract_archive() {
    local archive="$1"
    local dest="$2"

    mkdir -p "$dest"
    case "$archive" in
        *.tar.gz|*.tgz)
            tar -xzf "$archive" -C "$dest"
            ;;
        *.tar.bz2|*.tbz2)
            tar -xjf "$archive" -C "$dest"
            ;;
        *.zip)
            unzip -q "$archive" -d "$dest"
            ;;
        *)
            fail "Unsupported archive format: $archive"
            ;;
    esac
}

find_source_root() {
    local root="$1"
    if [ -f "$root/CMakeLists.txt" ] && [ -d "$root/td/telegram" ]; then
        echo "$root"
        return 0
    fi
    find "$root" -maxdepth 2 -type d | while read candidate; do
        if [ -f "$candidate/CMakeLists.txt" ] && [ -d "$candidate/td/telegram" ]; then
            echo "$candidate"
            return 0
        fi
    done | head -n 1
}

prove_tdlib_version() {
    local source_root="$1"
    local archive_name="${2:-}"
    local described=""

    if command -v git >/dev/null 2>&1 && [ -d "$source_root/.git" ]; then
        described="$(git -C "$source_root" describe --tags --exact-match 2>/dev/null || true)"
        if [ "$described" = "$TDLIB_VERSION" ]; then
            return 0
        fi
        if [ -n "$described" ]; then
            echo "TDLib source tag is $described, expected $TDLIB_VERSION."
            return 1
        fi
    fi

    case "$archive_name" in
        *td-${TDLIB_VERSION}.tar.gz|*td-${TDLIB_VERSION}.tgz|*td-${TDLIB_VERSION}.zip|*tdlib-${TDLIB_VERSION}.tar.gz|*tdlib-${TDLIB_VERSION}.zip|*${TDLIB_VERSION}*)
            return 0
            ;;
    esac

    return 1
}

check_prefix_file() {
    local root="$1"
    local rel="$2"
    local label="$3"
    if [ -n "$root" ] && [ ! -e "$root/$rel" ]; then
        fail "$label was not found at $root/$rel"
    fi
}

check_prefix_library() {
    local root="$1"
    local name="$2"
    local label="$3"
    if [ -n "$root" ] && [ ! -e "$root/lib/lib${name}.a" ] && [ ! -e "$root/lib/lib${name}.dylib" ]; then
        fail "$label was not found at $root/lib/lib${name}.a or $root/lib/lib${name}.dylib"
    fi
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --source)
            require_option_value "$@"
            SOURCE_PATH="${2:-}"
            shift 2
            ;;
        --archive)
            require_option_value "$@"
            ARCHIVE_PATH="${2:-}"
            shift 2
            ;;
        --build-dir)
            require_option_value "$@"
            BUILD_DIR="${2:-}"
            shift 2
            ;;
        --install-dir)
            require_option_value "$@"
            INSTALL_DIR="${2:-}"
            shift 2
            ;;
        --stage-dir)
            require_option_value "$@"
            STAGE_DIR="${2:-}"
            shift 2
            ;;
        --openssl-root)
            require_option_value "$@"
            OPENSSL_ROOT="${2:-}"
            shift 2
            ;;
        --zlib-root)
            require_option_value "$@"
            ZLIB_ROOT="${2:-}"
            shift 2
            ;;
        --cmake)
            require_option_value "$@"
            CMAKE_BIN="${2:-}"
            shift 2
            ;;
        --gperf)
            require_option_value "$@"
            GPERF_BIN="${2:-}"
            shift 2
            ;;
        --jobs)
            require_option_value "$@"
            JOBS="${2:-}"
            shift 2
            ;;
        --clean)
            CLEAN=1
            shift
            ;;
        --allow-unknown-tag)
            ALLOW_UNKNOWN_TAG=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            usage
            fail "Unknown option: $1"
            ;;
    esac
done

if [ -n "$SOURCE_PATH" ] && [ -n "$ARCHIVE_PATH" ]; then
    fail "Use either --source or --archive, not both."
fi
if [ -z "$SOURCE_PATH" ] && [ -z "$ARCHIVE_PATH" ]; then
    usage
    fail "Missing --source or --archive."
fi

mkdir -p "$(dirname "$BUILD_DIR")"
BUILD_DIR="$(abs_path "$BUILD_DIR")"
if [ -z "$INSTALL_DIR" ]; then
    INSTALL_DIR="$BUILD_DIR/install"
fi
if [ -z "$STAGE_DIR" ]; then
    STAGE_DIR="$BUILD_DIR/stage"
fi
mkdir -p "$(dirname "$INSTALL_DIR")" "$(dirname "$STAGE_DIR")"
INSTALL_DIR="$(abs_path "$INSTALL_DIR")"
STAGE_DIR="$(abs_path "$STAGE_DIR")"

if [ "$CLEAN" -eq 1 ]; then
    rm -rf "$BUILD_DIR"
fi

mkdir -p "$BUILD_DIR" "$INSTALL_DIR" "$STAGE_DIR"

if [ -z "${DEVELOPER_DIR:-}" ] && [ -d "/Applications/Xcode_6.2.app/Contents/Developer" ]; then
    export DEVELOPER_DIR="/Applications/Xcode_6.2.app/Contents/Developer"
fi

require_command "$CMAKE_BIN"
require_command "$GPERF_BIN"
require_command make
require_command xcrun
require_command file
require_command otool

if ! xcrun --find clang++ >/dev/null 2>&1; then
    fail "clang++ was not found through xcrun."
fi

if [ -z "$JOBS" ]; then
    JOBS="$(default_jobs)"
fi

SOURCE_ROOT=""
ARCHIVE_BASENAME=""
if [ -n "$SOURCE_PATH" ]; then
    [ -d "$SOURCE_PATH" ] || fail "TDLib source directory was not found: $SOURCE_PATH"
    SOURCE_ROOT="$(abs_path "$SOURCE_PATH")"
else
    [ -f "$ARCHIVE_PATH" ] || fail "TDLib archive was not found: $ARCHIVE_PATH"
    ARCHIVE_PATH="$(abs_path "$ARCHIVE_PATH")"
    ARCHIVE_BASENAME="$(basename "$ARCHIVE_PATH")"
    EXTRACT_ROOT="$BUILD_DIR/src"
    rm -rf "$EXTRACT_ROOT"
    extract_archive "$ARCHIVE_PATH" "$EXTRACT_ROOT"
    SOURCE_ROOT="$(find_source_root "$EXTRACT_ROOT")"
fi

if [ -z "$SOURCE_ROOT" ] || [ ! -f "$SOURCE_ROOT/CMakeLists.txt" ] || [ ! -d "$SOURCE_ROOT/td/telegram" ]; then
    fail "TDLib source root was not found or does not look like TDLib."
fi

if ! prove_tdlib_version "$SOURCE_ROOT" "$ARCHIVE_BASENAME"; then
    if [ "$ALLOW_UNKNOWN_TAG" -eq 1 ]; then
        echo "Warning: could not prove source tag $TDLIB_VERSION; continuing because --allow-unknown-tag was supplied."
    else
        fail "Could not prove TDLib source version $TDLIB_VERSION. Use --allow-unknown-tag to continue anyway."
    fi
fi

if [ -n "$OPENSSL_ROOT" ]; then
    OPENSSL_ROOT="$(abs_path "$OPENSSL_ROOT")"
    check_prefix_file "$OPENSSL_ROOT" "include/openssl/ssl.h" "OpenSSL header"
    check_prefix_library "$OPENSSL_ROOT" "ssl" "OpenSSL libssl"
    check_prefix_library "$OPENSSL_ROOT" "crypto" "OpenSSL libcrypto"
fi
if [ -n "$ZLIB_ROOT" ]; then
    ZLIB_ROOT="$(abs_path "$ZLIB_ROOT")"
    check_prefix_file "$ZLIB_ROOT" "include/zlib.h" "zlib header"
    check_prefix_library "$ZLIB_ROOT" "z" "zlib library"
fi

SDK_NAME="macosx"
if xcrun --sdk macosx10.9 --show-sdk-path >/dev/null 2>&1; then
    SDK_NAME="macosx10.9"
fi
SDK_PATH="$(xcrun --sdk "$SDK_NAME" --show-sdk-path 2>/dev/null || true)"

CONFIGURE_DIR="$BUILD_DIR/build"
mkdir -p "$CONFIGURE_DIR"

CMAKE_ARGS=(
    "$SOURCE_ROOT"
    "-DCMAKE_BUILD_TYPE=Release"
    "-DCMAKE_INSTALL_PREFIX=$INSTALL_DIR"
    "-DCMAKE_OSX_ARCHITECTURES=$ARCH"
    "-DCMAKE_OSX_DEPLOYMENT_TARGET=$DEPLOYMENT_TARGET"
    "-DCMAKE_C_FLAGS=-mmacosx-version-min=$DEPLOYMENT_TARGET"
    "-DCMAKE_CXX_FLAGS=-stdlib=libc++ -mmacosx-version-min=$DEPLOYMENT_TARGET"
    "-DCMAKE_SHARED_LINKER_FLAGS=-mmacosx-version-min=$DEPLOYMENT_TARGET"
    "-DOPENSSL_USE_STATIC_LIBS=TRUE"
    "-DZLIB_USE_STATIC_LIBS=TRUE"
    "-DTD_ENABLE_JNI=OFF"
    "-DTD_ENABLE_DOTNET=OFF"
)

if [ -n "$SDK_PATH" ]; then
    CMAKE_ARGS+=("-DCMAKE_OSX_SYSROOT=$SDK_PATH")
fi
if [ -n "$OPENSSL_ROOT" ]; then
    CMAKE_ARGS+=("-DOPENSSL_ROOT_DIR=$OPENSSL_ROOT")
fi
if [ -n "$ZLIB_ROOT" ]; then
    CMAKE_ARGS+=("-DZLIB_ROOT=$ZLIB_ROOT")
fi

export MACOSX_DEPLOYMENT_TARGET="$DEPLOYMENT_TARGET"

echo "Building TDLib $TDLIB_VERSION tdjson for OS X $DEPLOYMENT_TARGET ($ARCH)."
echo "Source: $SOURCE_ROOT"
echo "Build:  $CONFIGURE_DIR"
echo "Stage:  $STAGE_DIR/Frameworks"

set +e
(
    cd "$CONFIGURE_DIR"
    "$CMAKE_BIN" "${CMAKE_ARGS[@]}"
    "$CMAKE_BIN" --build . --target tdjson -- -j "$JOBS"
) 2>&1 | tee "$BUILD_DIR/build.log"
BUILD_STATUS=${PIPESTATUS[0]}
set -e

if [ "$BUILD_STATUS" -ne 0 ]; then
    fail "TDLib build failed. Check $BUILD_DIR/build.log"
fi

TDJSON_BUILT="$(find "$CONFIGURE_DIR" -name libtdjson.dylib -type f | head -n 1)"
if [ -z "$TDJSON_BUILT" ]; then
    fail "Build succeeded, but libtdjson.dylib was not found under $CONFIGURE_DIR."
fi

mkdir -p "$STAGE_DIR/Frameworks"
ditto "$TDJSON_BUILT" "$STAGE_DIR/Frameworks/libtdjson.dylib"

"$SCRIPT_DIR/check_tdjson_legacy.sh" "$STAGE_DIR/Frameworks/libtdjson.dylib" | tee "$BUILD_DIR/validation.txt"

echo
echo "Created staged TDLib dylib:"
echo "$STAGE_DIR/Frameworks/libtdjson.dylib"
echo
echo "Bundle it into Telegraphica with:"
echo "TELEGRAPHICA_TDJSON_PATH=\"$STAGE_DIR/Frameworks/libtdjson.dylib\" ./build_legacy.sh"
