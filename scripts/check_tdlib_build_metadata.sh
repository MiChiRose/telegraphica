#!/bin/bash
set -euo pipefail

TDJSON_PATH="${1:-}"
METADATA_PATH="${2:-}"
ARCH="${TELEGRAPHICA_ARCH:-x86_64}"

if [ -z "$TDJSON_PATH" ] || [ -z "$METADATA_PATH" ]; then
    echo "Usage: $0 /path/to/libtdjson.dylib /path/to/metadata.tsv"
    exit 1
fi
if [ ! -f "$TDJSON_PATH" ] || [ ! -f "$METADATA_PATH" ]; then
    echo "TDLib binary or metadata file is missing."
    exit 1
fi

HEADER="$(sed -n '1p' "$METADATA_PATH")"
EXPECTED_HEADER="$(printf 'lane\tbinary_name\ttdlib_version\tsource_tag\tsource_commit\tmtproto_layer\trelease_status\tarchitecture\tminimum_os\tinstall_name\tsha256\texports_sha256')"
if [ "$HEADER" != "$EXPECTED_HEADER" ]; then
    echo "TDLib metadata has an unexpected schema: $METADATA_PATH"
    exit 1
fi
if [ "$(wc -l < "$METADATA_PATH" | tr -d ' ')" -ne 2 ]; then
    echo "TDLib metadata must contain exactly one build row."
    exit 1
fi

METADATA_ARCH="$(awk -F '\t' 'NR == 2 { print $8 }' "$METADATA_PATH")"
METADATA_MINIMUM="$(awk -F '\t' 'NR == 2 { print $9 }' "$METADATA_PATH")"
METADATA_SHA="$(awk -F '\t' 'NR == 2 { print $11 }' "$METADATA_PATH")"
METADATA_EXPORTS_SHA="$(awk -F '\t' 'NR == 2 { print $12 }' "$METADATA_PATH")"
ACTUAL_SHA="$(shasum -a 256 "$TDJSON_PATH" | awk '{ print $1 }')"
if [ "$METADATA_ARCH" != "$ARCH" ]; then
    echo "TDLib metadata architecture is $METADATA_ARCH, expected $ARCH."
    exit 1
fi
if [ -z "$METADATA_MINIMUM" ] || [ "$METADATA_SHA" != "$ACTUAL_SHA" ]; then
    echo "TDLib metadata does not match the binary."
    exit 1
fi

EXPORTS_PATH="${METADATA_PATH%.tsv}.exports.txt"
if [ ! -f "$EXPORTS_PATH" ]; then
    echo "TDLib ABI export list is missing: $EXPORTS_PATH"
    exit 1
fi
ACTUAL_EXPORTS_SHA="$(shasum -a 256 "$EXPORTS_PATH" | awk '{ print $1 }')"
if [ "$METADATA_EXPORTS_SHA" != "$ACTUAL_EXPORTS_SHA" ]; then
    echo "TDLib ABI export list does not match its recorded digest."
    exit 1
fi

echo "TDLib build metadata check passed."
