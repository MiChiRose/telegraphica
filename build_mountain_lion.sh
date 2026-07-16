#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

if [ -z "${DEVELOPER_DIR:-}" ] && [ -d "/Applications/Xcode 5.1.1.app/Contents/Developer" ]; then
    XCODE5_DEVELOPER_DIR="/Applications/Xcode 5.1.1.app/Contents/Developer"
    XCODE5_LINK="${TMPDIR:-/tmp}/telegraphica-xcode-5.1.1-developer"
    if [ ! -e "$XCODE5_LINK" ]; then
        ln -s "$XCODE5_DEVELOPER_DIR" "$XCODE5_LINK"
    fi
    if [ -d "$XCODE5_LINK" ]; then
        export DEVELOPER_DIR="$XCODE5_LINK"
    else
        export DEVELOPER_DIR="$XCODE5_DEVELOPER_DIR"
    fi
fi

export LC_ALL=C
export LANG=C
export TELEGRAPHICA_DEPLOYMENT_TARGET="${TELEGRAPHICA_DEPLOYMENT_TARGET:-10.8}"
export MACOSX_DEPLOYMENT_TARGET="$TELEGRAPHICA_DEPLOYMENT_TARGET"

if [ -z "${SDKROOT:-}" ]; then
    SDK_PATH="$(xcrun --sdk macosx10.9 --show-sdk-path 2>/dev/null || xcrun --sdk macosx --show-sdk-path)"
    SDK_LINK="${TMPDIR:-/tmp}/telegraphica-macosx-sdk"
    if [ ! -e "$SDK_LINK" ]; then
        ln -s "$SDK_PATH" "$SDK_LINK"
    fi
    if [ -d "$SDK_LINK" ]; then
        export SDKROOT="$SDK_LINK"
    fi
fi

./build_legacy.sh
