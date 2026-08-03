#!/bin/bash
set -euo pipefail

TDJSON_PATH="${1:-}"
OUTPUT_PATH="${2:-}"
LANE="${3:-unknown}"
TDLIB_VERSION="${4:-unknown}"
SOURCE_TAG="${5:-unknown}"
SOURCE_COMMIT="${6:-unknown}"
MTPROTO_LAYER="${7:-unknown}"
RELEASE_STATUS="${8:-experimental}"
ARCH="${TELEGRAPHICA_ARCH:-x86_64}"

if [ -z "$TDJSON_PATH" ] || [ -z "$OUTPUT_PATH" ]; then
    echo "Usage: $0 /path/to/libtdjson.dylib /path/to/metadata.tsv lane version tag commit layer status"
    exit 1
fi
if [ ! -f "$TDJSON_PATH" ]; then
    echo "TDLib JSON dylib was not found: $TDJSON_PATH"
    exit 1
fi

for command_name in nm otool shasum awk sort; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        echo "$command_name was not found."
        exit 1
    fi
done

sanitize_field() {
    printf "%s" "$1" | tr '\t\r\n' '   '
}

LOAD_COMMANDS="$(otool -arch "$ARCH" -l "$TDJSON_PATH" 2>/dev/null || true)"
MINIMUM_OS="$(printf "%s\n" "$LOAD_COMMANDS" | awk '
    /LC_VERSION_MIN_MACOSX/ { found = 1 }
    found && /version / { print $2; exit }
')"
if [ -z "$MINIMUM_OS" ]; then
    echo "Could not determine LC_VERSION_MIN_MACOSX for $TDJSON_PATH"
    exit 1
fi
if printf "%s\n" "$LOAD_COMMANDS" | grep -q "LC_BUILD_VERSION"; then
    echo "TDLib uses LC_BUILD_VERSION and cannot be recorded as a legacy build."
    exit 1
fi

INSTALL_NAME="$(otool -arch "$ARCH" -D "$TDJSON_PATH" 2>/dev/null | awk 'NR == 2 { print $1 }')"
if [ "$TDLIB_VERSION" = "unknown" ] && [ -n "$INSTALL_NAME" ]; then
    TDLIB_VERSION="$(printf "%s\n" "$INSTALL_NAME" | sed -n 's#.*libtdjson\.\([0-9][0-9.]*\)\.dylib#\1#p')"
    if [ -z "$TDLIB_VERSION" ]; then
        TDLIB_VERSION="unknown"
    fi
fi

OUTPUT_DIR="$(dirname "$OUTPUT_PATH")"
mkdir -p "$OUTPUT_DIR"
EXPORTS_PATH="${OUTPUT_PATH%.tsv}.exports.txt"
TEMP_EXPORTS="$(mktemp "${TMPDIR:-/tmp}/telegraphica-tdjson-exports.XXXXXX")"
cleanup() {
    rm -f "$TEMP_EXPORTS"
}
trap cleanup EXIT

nm -arch "$ARCH" -g "$TDJSON_PATH" 2>/dev/null |
    awk '{ print $NF }' |
    grep -E '^_?td_' |
    sort -u > "$TEMP_EXPORTS" || true

for required_symbol in \
    td_json_client_create \
    td_json_client_destroy \
    td_json_client_execute \
    td_json_client_receive \
    td_json_client_send
do
    if ! grep -E -q "^_?${required_symbol}$" "$TEMP_EXPORTS"; then
        echo "TDLib ABI is missing required export: $required_symbol"
        exit 1
    fi
done

ditto "$TEMP_EXPORTS" "$EXPORTS_PATH"
SHA256="$(shasum -a 256 "$TDJSON_PATH" | awk '{ print $1 }')"
EXPORTS_SHA256="$(shasum -a 256 "$EXPORTS_PATH" | awk '{ print $1 }')"

printf "lane\tbinary_name\ttdlib_version\tsource_tag\tsource_commit\tmtproto_layer\trelease_status\tarchitecture\tminimum_os\tinstall_name\tsha256\texports_sha256\n" > "$OUTPUT_PATH"
printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
    "$(sanitize_field "$LANE")" \
    "$(sanitize_field "$(basename "$TDJSON_PATH")")" \
    "$(sanitize_field "$TDLIB_VERSION")" \
    "$(sanitize_field "$SOURCE_TAG")" \
    "$(sanitize_field "$SOURCE_COMMIT")" \
    "$(sanitize_field "$MTPROTO_LAYER")" \
    "$(sanitize_field "$RELEASE_STATUS")" \
    "$(sanitize_field "$ARCH")" \
    "$(sanitize_field "$MINIMUM_OS")" \
    "$(sanitize_field "$INSTALL_NAME")" \
    "$SHA256" \
    "$EXPORTS_SHA256" >> "$OUTPUT_PATH"

echo "TDLib build metadata: $OUTPUT_PATH"
echo "TDLib exported ABI:  $EXPORTS_PATH"
