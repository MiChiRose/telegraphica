#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

ARCH="${TELEGRAPHICA_ARCH:-x86_64}"
DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET:-10.8}"
TDJSON_PATH="${1:-${TELEGRAPHICA_TDJSON_PATH:-}}"
REQUIRE_PORTABLE_DEPS="${TELEGRAPHICA_REQUIRE_PORTABLE_TDJSON:-0}"

usage() {
    echo "Usage: $0 /path/to/libtdjson.dylib"
    echo
    echo "Checks that a TDLib JSON dylib is plausible for Telegraphica's"
    echo "OS X $DEPLOYMENT_TARGET / $ARCH legacy lane."
}

version_gt() {
    awk -v left="$1" -v right="$2" '
        BEGIN {
            split(left, a, ".");
            split(right, b, ".");
            for (i = 1; i <= 3; i++) {
                av = (a[i] == "" ? 0 : a[i]) + 0;
                bv = (b[i] == "" ? 0 : b[i]) + 0;
                if (av > bv) {
                    exit 0;
                }
                if (av < bv) {
                    exit 1;
                }
            }
            exit 1;
        }
    '
}

binary_contains_arch() {
    local binary_path="$1"
    local expected_arch="$2"
    local lipo_output=""

    lipo_output="$(lipo -archs "$binary_path" 2>/dev/null || true)"
    if [ -z "$lipo_output" ]; then
        lipo_output="$(lipo -info "$binary_path" 2>/dev/null || true)"
    fi
    if [ -n "$lipo_output" ] && echo "$lipo_output" | tr ' :' '\n\n' | grep -qx "$expected_arch"; then
        return 0
    fi

    return 1
}

require_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "$1 was not found."
        exit 1
    fi
}

if [ "$TDJSON_PATH" = "-h" ] || [ "$TDJSON_PATH" = "--help" ]; then
    usage
    exit 0
fi

if [ -z "$TDJSON_PATH" ]; then
    usage
    exit 1
fi

if [ ! -f "$TDJSON_PATH" ]; then
    echo "TDLib JSON dylib was not found: $TDJSON_PATH"
    exit 1
fi

require_command file
require_command lipo
require_command nm
require_command otool

echo "Checking $TDJSON_PATH"
file "$TDJSON_PATH"

if ! binary_contains_arch "$TDJSON_PATH" "$ARCH"; then
    echo "libtdjson.dylib does not contain $ARCH."
    exit 1
fi

OTOOL_LOAD_COMMANDS="$(otool -arch "$ARCH" -l "$TDJSON_PATH" 2>/dev/null || true)"
if [ -z "$OTOOL_LOAD_COMMANDS" ]; then
    echo "Could not inspect $ARCH load commands in libtdjson.dylib."
    exit 1
fi

MIN_MACHO="$(echo "$OTOOL_LOAD_COMMANDS" | awk '/LC_VERSION_MIN_MACOSX/{found=1} found && /version /{print $2; exit}')"
if [ -z "$MIN_MACHO" ]; then
    if echo "$OTOOL_LOAD_COMMANDS" | grep -q "LC_BUILD_VERSION"; then
        echo "libtdjson.dylib uses LC_BUILD_VERSION instead of LC_VERSION_MIN_MACOSX."
        echo "Build it on the legacy lane or with an SDK/toolchain that emits a $DEPLOYMENT_TARGET-safe load command."
        exit 1
    fi
    echo "Could not find LC_VERSION_MIN_MACOSX in libtdjson.dylib."
    exit 1
fi

if version_gt "$MIN_MACHO" "$DEPLOYMENT_TARGET"; then
    echo "libtdjson.dylib minimum system version is $MIN_MACHO, expected <= $DEPLOYMENT_TARGET."
    exit 1
fi

echo "Mach-O minimum system version: $MIN_MACHO"

NM_SYMBOLS="$(nm -arch "$ARCH" -g "$TDJSON_PATH" 2>/dev/null || true)"
if [ -z "$NM_SYMBOLS" ]; then
    echo "Could not inspect $ARCH exported symbols in libtdjson.dylib."
    exit 1
fi
if ! echo "$NM_SYMBOLS" | grep -E -q '(^|[[:space:]])_?td_json_client_execute$'; then
    echo "libtdjson.dylib does not export td_json_client_execute."
    exit 1
fi
if ! echo "$NM_SYMBOLS" | grep -E -q '(^|[[:space:]])_?td_json_client_create$'; then
    echo "libtdjson.dylib does not export td_json_client_create."
    exit 1
fi
if ! echo "$NM_SYMBOLS" | grep -E -q '(^|[[:space:]])_?td_json_client_send$'; then
    echo "libtdjson.dylib does not export td_json_client_send."
    exit 1
fi
if ! echo "$NM_SYMBOLS" | grep -E -q '(^|[[:space:]])_?td_json_client_receive$'; then
    echo "libtdjson.dylib does not export td_json_client_receive."
    exit 1
fi
if ! echo "$NM_SYMBOLS" | grep -E -q '(^|[[:space:]])_?td_json_client_destroy$'; then
    echo "libtdjson.dylib does not export td_json_client_destroy."
    exit 1
fi

echo "Linked libraries:"
OTOOL_LINKED_LIBS="$(otool -arch "$ARCH" -L "$TDJSON_PATH" 2>/dev/null || true)"
if [ -z "$OTOOL_LINKED_LIBS" ]; then
    echo "Could not inspect $ARCH linked libraries in libtdjson.dylib."
    exit 1
fi
echo "$OTOOL_LINKED_LIBS"

NON_SYSTEM_DEPS="$(echo "$OTOOL_LINKED_LIBS" | awk 'NR > 2 {print $1}' | grep -E -v '^(/usr/lib/|/System/Library/|@loader_path/|@executable_path/)' || true)"
if [ -n "$NON_SYSTEM_DEPS" ]; then
    echo
    echo "libtdjson.dylib has non-system dependencies:"
    echo "$NON_SYSTEM_DEPS"
    echo "For the portable app bundle, prefer static OpenSSL/zlib or rewrite/copy these dylibs into Contents/Frameworks."
    if [ "$REQUIRE_PORTABLE_DEPS" = "1" ]; then
        echo "Portable TDLib dependency check failed."
        exit 1
    fi
fi

echo "TDLib JSON dylib check passed."
