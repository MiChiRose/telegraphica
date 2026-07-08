#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

ARCHIVE_PATH=""
OPENSSL_ROOT=""
ZLIB_ROOT=""
CMAKE_BIN=""
GPERF_BIN=""
JOBS=""
OPEN_AFTER_BUILD=0
TDLIB_BUILD_DIR="$ROOT_DIR/build-tdlib-legacy"

usage() {
    cat <<EOF
Usage:
  $0 --archive /path/to/td-v1.8.0.tar.gz --openssl-root /opt/local [options]

Options:
  --tdlib-build-dir PATH  default: build-tdlib-legacy
  --zlib-root PATH        optional zlib prefix
  --cmake PATH            optional cmake binary
  --gperf PATH            optional gperf binary
  --jobs N                optional build job count
  --open                  open Telegraphica.app after a successful rebuild
  -h, --help              show this help

This script rebuilds TDLib, finds the staged libtdjson.dylib wherever the
legacy TDLib script produced it, bundles it into Telegraphica, and rebuilds
the app for OS X 10.9.
EOF
}

fail() {
    echo "$1"
    exit 1
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

resolve_symlink_once() {
    local path="$1"
    local target=""
    local dir=""

    if [ -L "$path" ]; then
        target="$(readlink "$path" || true)"
        if [ -n "$target" ]; then
            case "$target" in
                /*)
                    path="$target"
                    ;;
                *)
                    dir="$(dirname "$path")"
                    path="$dir/$target"
                    ;;
            esac
        fi
    fi

    echo "$path"
}

find_tdjson_dylib() {
    local root="$1"
    local exact=""
    local resolved=""
    local versioned=""

    exact="$(find "$root" -path '*/stage/Frameworks/libtdjson.dylib' -print | head -n 1)"
    if [ -n "$exact" ]; then
        resolved="$(resolve_symlink_once "$exact")"
        if [ -f "$resolved" ]; then
            echo "$resolved"
            return 0
        fi
    fi

    exact="$(find "$root" -name libtdjson.dylib -print | head -n 1)"
    if [ -n "$exact" ]; then
        resolved="$(resolve_symlink_once "$exact")"
        if [ -f "$resolved" ]; then
            echo "$resolved"
            return 0
        fi
    fi

    versioned="$(find "$root" -name 'libtdjson*.dylib' -type f -print | sort | head -n 1)"
    if [ -n "$versioned" ]; then
        echo "$versioned"
        return 0
    fi

    return 1
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --archive)
            require_option_value "$@"
            ARCHIVE_PATH="$(abs_path "$2")"
            shift 2
            ;;
        --openssl-root)
            require_option_value "$@"
            OPENSSL_ROOT="$(abs_path "$2")"
            shift 2
            ;;
        --zlib-root)
            require_option_value "$@"
            ZLIB_ROOT="$(abs_path "$2")"
            shift 2
            ;;
        --cmake)
            require_option_value "$@"
            CMAKE_BIN="$2"
            shift 2
            ;;
        --gperf)
            require_option_value "$@"
            GPERF_BIN="$2"
            shift 2
            ;;
        --jobs)
            require_option_value "$@"
            JOBS="$2"
            shift 2
            ;;
        --tdlib-build-dir)
            require_option_value "$@"
            TDLIB_BUILD_DIR="$(abs_path "$2")"
            shift 2
            ;;
        --open)
            OPEN_AFTER_BUILD=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            fail "Unknown option: $1"
            ;;
    esac
done

if [ -z "$ARCHIVE_PATH" ]; then
    fail "--archive is required."
fi

if [ ! -f "$ARCHIVE_PATH" ]; then
    fail "TDLib archive was not found: $ARCHIVE_PATH"
fi

if [ -z "$OPENSSL_ROOT" ]; then
    fail "--openssl-root is required."
fi

cd "$ROOT_DIR"

TDLIB_ARGS=(
    "--archive" "$ARCHIVE_PATH"
    "--openssl-root" "$OPENSSL_ROOT"
    "--build-dir" "$TDLIB_BUILD_DIR"
    "--clean"
)

if [ -n "$ZLIB_ROOT" ]; then
    TDLIB_ARGS+=("--zlib-root" "$ZLIB_ROOT")
fi

if [ -n "$CMAKE_BIN" ]; then
    TDLIB_ARGS+=("--cmake" "$CMAKE_BIN")
fi

if [ -n "$GPERF_BIN" ]; then
    TDLIB_ARGS+=("--gperf" "$GPERF_BIN")
fi

if [ -n "$JOBS" ]; then
    TDLIB_ARGS+=("--jobs" "$JOBS")
fi

echo "Rebuilding TDLib for Telegraphica..."
"$SCRIPT_DIR/build_tdlib_legacy.sh" "${TDLIB_ARGS[@]}"

TDJSON_PATH="$(find_tdjson_dylib "$TDLIB_BUILD_DIR" || true)"
if [ -z "$TDJSON_PATH" ]; then
    echo "Could not find libtdjson.dylib under $TDLIB_BUILD_DIR."
    echo "TDLib candidates:"
    find "$TDLIB_BUILD_DIR" \( -name '*tdjson*' -o -name 'libtd*.dylib' \) -print | sed -n '1,80p'
    exit 1
fi

echo "Bundling TDLib dylib:"
echo "$TDJSON_PATH"

TELEGRAPHICA_TDJSON_PATH="$TDJSON_PATH" "$ROOT_DIR/build_legacy.sh"

if [ "$OPEN_AFTER_BUILD" -eq 1 ]; then
    open "$ROOT_DIR/build-legacy/Release/Telegraphica.app"
fi
