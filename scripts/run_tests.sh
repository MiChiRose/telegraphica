#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

PYTHON_BIN=""
if command -v python3 >/dev/null 2>&1; then
    PYTHON_BIN="$(command -v python3)"
elif command -v python >/dev/null 2>&1; then
    PYTHON_BIN="$(command -v python)"
else
    echo "python3 or python is required to run Telegraphica tests."
    exit 1
fi

ARCH="${TELEGRAPHICA_TEST_ARCH:-x86_64}"
SDK_NAME="${TELEGRAPHICA_TEST_SDK:-macosx}"
if xcodebuild -showsdks 2>/dev/null | grep -q "macosx10\.9"; then
    SDK_NAME="${TELEGRAPHICA_TEST_SDK:-macosx10.9}"
fi

CLANG="$(xcrun --sdk "$SDK_NAME" --find clang 2>/dev/null || xcrun -f clang 2>/dev/null || command -v clang || true)"
if [ -z "$CLANG" ]; then
    echo "clang is required to compile Telegraphica test probes."
    exit 1
fi

SDK_PATH="$(xcrun --sdk "$SDK_NAME" --show-sdk-path 2>/dev/null || true)"
BUILD_DIR="$(mktemp -d "${TMPDIR:-/tmp}/telegraphica-tests.XXXXXX")"
TEST_HOME="$BUILD_DIR/home"
mkdir -p "$TEST_HOME"

cleanup() {
    rm -rf "$BUILD_DIR"
}
trap cleanup EXIT

echo "== Telegraphica static compatibility =="
"$PYTHON_BIN" scripts/check_legacy_compat.py
"$PYTHON_BIN" scripts/test_static_project.py
"$PYTHON_BIN" scripts/test_security_hardening.py

echo "== Shell syntax =="
bash -n build_legacy.sh
for script in scripts/*.sh; do
    bash -n "$script"
done

if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "== Whitespace =="
    git diff --check
fi

echo "== Mock TDLib event reducer =="
"$PYTHON_BIN" Tests/mock_tdlib_event_probe.py

echo "== Workshop game logic =="
Tests/Workshop/run_game_tests.sh

echo "== Workshop installer state =="
Tests/Workshop/run_installer_state_tests.sh

echo "== Media preview gate =="
scripts/check_media_item_support.sh "$ARCH" "$BUILD_DIR/media-item-support" "$SDK_NAME"

echo "== Core logic probe =="
COMPILE_FLAGS=(
    -arch "$ARCH"
    -mmacosx-version-min=10.9
    -fblocks
    -fno-objc-arc
    -I"$ROOT_DIR/Sources/Core"
    -I"$ROOT_DIR/Sources/Media"
    -I"$ROOT_DIR/Sources/Services"
    -I"$ROOT_DIR/Sources/UI"
)
if [ -n "$SDK_PATH" ]; then
    COMPILE_FLAGS+=("-isysroot" "$SDK_PATH")
fi

"$CLANG" \
    "${COMPILE_FLAGS[@]}" \
    Tests/core_logic_probe.m \
    Sources/Core/TGMessageItem.m \
    Sources/Core/TGMessagePollSupport.m \
    Sources/Core/TGOutgoingMessageTextChunker.m \
    Sources/Media/TGMediaItemSupport.m \
    Sources/Media/TGOpusVoiceTranscoder.m \
    Sources/Services/TGLogger.m \
    Sources/Services/TGResourcePolicy.m \
    Sources/UI/TGChatDisplayPreferences.m \
    Sources/UI/TGLocalization.m \
    Sources/UI/TGMessageLayoutSupport.m \
    Sources/UI/TGTheme.m \
    Sources/UI/TGVisualWorldThemeSpec.m \
    -framework Cocoa \
    -o "$BUILD_DIR/core_logic_probe"

HOME="$TEST_HOME" "$BUILD_DIR/core_logic_probe"

echo "Telegraphica tests passed."
