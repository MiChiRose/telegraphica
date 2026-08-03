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
DEPLOYMENT_TARGET="${TELEGRAPHICA_TEST_DEPLOYMENT_TARGET:-10.8}"
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
"$PYTHON_BIN" scripts/check_free_feature_policy.py
"$PYTHON_BIN" scripts/test_static_project.py
"$PYTHON_BIN" scripts/test_security_hardening.py

echo "== Shell syntax =="
bash -n build_legacy.sh
for script in scripts/*.sh; do
    bash -n "$script"
done

if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "== Whitespace =="
    # Unified patch payloads intentionally contain context whitespace.
    git diff --check -- . ':(exclude)Vendor/patches/*.patch'
fi

echo "== Mock TDLib event reducer =="
"$PYTHON_BIN" Tests/mock_tdlib_event_probe.py

echo "== Workshop game logic =="
Tests/Workshop/run_game_tests.sh

echo "== Workshop installer state =="
Tests/Workshop/run_installer_state_tests.sh

echo "== Media Workbench =="
Tests/Workshop/run_media_workbench_tests.sh

echo "== Media preview gate =="
scripts/check_media_item_support.sh "$ARCH" "$BUILD_DIR/media-item-support" "$SDK_NAME"

COMPILE_FLAGS=(
    -arch "$ARCH"
    "-mmacosx-version-min=$DEPLOYMENT_TARGET"
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

echo "== Asynchronous animated image loader =="
"$CLANG" "${COMPILE_FLAGS[@]}" \
    Tests/animated_image_loader_probe.m \
    Sources/Media/TGAnimatedImageLoader.m \
    -framework Cocoa \
    -framework ImageIO \
    -o "$BUILD_DIR/animated-image-loader-probe"
HOME="$TEST_HOME" "$BUILD_DIR/animated-image-loader-probe"

echo "== Utility window request lifetime =="
"$CLANG" "${COMPILE_FLAGS[@]}" \
    Tests/utility_window_lifetime_probe.m \
    Sources/UI/TGUtilityWindowLifetime.m \
    -framework Foundation \
    -o "$BUILD_DIR/utility-window-lifetime-probe"
HOME="$TEST_HOME" "$BUILD_DIR/utility-window-lifetime-probe"

echo "== Legacy accessibility support =="
"$CLANG" "${COMPILE_FLAGS[@]}" \
    Tests/accessibility_support_probe.m \
    Sources/UI/TGAccessibilitySupport.m \
    -framework Cocoa \
    -o "$BUILD_DIR/accessibility-support-probe"
HOME="$TEST_HOME" "$BUILD_DIR/accessibility-support-probe"

echo "== Persistent download queue =="
"$CLANG" "${COMPILE_FLAGS[@]}" \
    Tests/download_queue_store_probe.m \
    Sources/Services/TGDownloadQueueStore.m \
    -framework Foundation \
    -o "$BUILD_DIR/download-queue-store-probe"
HOME="$TEST_HOME" "$BUILD_DIR/download-queue-store-probe"

echo "== TDLib capability registry =="
"$CLANG" \
    "${COMPILE_FLAGS[@]}" \
    Tests/tdlib_capabilities_probe.m \
    Sources/Core/TGTDLibCapabilities.m \
    -framework Foundation \
    -o "$BUILD_DIR/tdlib_capabilities_probe"

HOME="$TEST_HOME" "$BUILD_DIR/tdlib_capabilities_probe"

echo "== TDLib message search requests =="
"$CLANG" \
    "${COMPILE_FLAGS[@]}" \
    -Wno-incomplete-implementation \
    -Wno-objc-protocol-method-implementation \
    Tests/tdlib_search_request_probe.m \
    Sources/Core/TGTDLibClient+Search.m \
    -framework Foundation \
    -o "$BUILD_DIR/tdlib-search-request-probe"
HOME="$TEST_HOME" "$BUILD_DIR/tdlib-search-request-probe"

echo "== TDLib storage requests =="
"$CLANG" \
    "${COMPILE_FLAGS[@]}" \
    -Wno-incomplete-implementation \
    -Wno-objc-protocol-method-implementation \
    Tests/tdlib_storage_request_probe.m \
    Sources/Core/TGTDLibClient+Storage.m \
    Sources/Services/TGStorageCleanupPolicy.m \
    -framework Foundation \
    -o "$BUILD_DIR/tdlib-storage-request-probe"
HOME="$TEST_HOME" "$BUILD_DIR/tdlib-storage-request-probe"

echo "== TDLib file requests =="
"$CLANG" \
    "${COMPILE_FLAGS[@]}" \
    -Wno-incomplete-implementation \
    -Wno-objc-protocol-method-implementation \
    Tests/tdlib_file_request_probe.m \
    Sources/Core/TGTDLibClient+Files.m \
    -framework Foundation \
    -o "$BUILD_DIR/tdlib-file-request-probe"
HOME="$TEST_HOME" "$BUILD_DIR/tdlib-file-request-probe"

echo "== Authorization flow fixtures =="
"$CLANG" \
    "${COMPILE_FLAGS[@]}" \
    Tests/authorization_flow_probe.m \
    Sources/Core/TGAuthorizationFlow.m \
    -framework Foundation \
    -o "$BUILD_DIR/authorization_flow_probe"

HOME="$TEST_HOME" "$BUILD_DIR/authorization_flow_probe"

echo "== Formatted text codec =="
"$CLANG" \
    "${COMPILE_FLAGS[@]}" \
    Tests/formatted_text_codec_probe.m \
    Sources/Core/TGFormattedTextCodec.m \
    -framework Foundation \
    -o "$BUILD_DIR/formatted_text_codec_probe"

HOME="$TEST_HOME" "$BUILD_DIR/formatted_text_codec_probe"

echo "== Secret chat key visualization =="
"$CLANG" \
    "${COMPILE_FLAGS[@]}" \
    Tests/secret_chat_key_probe.m \
    Sources/Core/TGSecretChatKey.m \
    -framework Foundation \
    -o "$BUILD_DIR/secret_chat_key_probe"

HOME="$TEST_HOME" "$BUILD_DIR/secret_chat_key_probe"

echo "== Server reaction catalog =="
"$CLANG" \
    "${COMPILE_FLAGS[@]}" \
    Tests/reaction_catalog_probe.m \
    Sources/Core/TGReactionCatalog.m \
    -framework Foundation \
    -o "$BUILD_DIR/reaction_catalog_probe"

HOME="$TEST_HOME" "$BUILD_DIR/reaction_catalog_probe"

echo "== Added reaction users =="
"$CLANG" \
    "${COMPILE_FLAGS[@]}" \
    Tests/added_reactions_probe.m \
    Sources/Core/TGAddedReactionsParser.m \
    -framework Foundation \
    -o "$BUILD_DIR/added_reactions_probe"

HOME="$TEST_HOME" "$BUILD_DIR/added_reactions_probe"

echo "== Cancellable TDLib operation =="
"$CLANG" \
    "${COMPILE_FLAGS[@]}" \
    Tests/tdlib_operation_probe.m \
    Sources/Core/TGTDLibOperation.m \
    -framework Foundation \
    -o "$BUILD_DIR/tdlib_operation_probe"

HOME="$TEST_HOME" "$BUILD_DIR/tdlib_operation_probe"

echo "== Media image loader =="
"$CLANG" \
    "${COMPILE_FLAGS[@]}" \
    Tests/media_image_loader_probe.m \
    Sources/Media/TGMediaImageLoader.m \
    Sources/Media/TGMessageThumbnailPrefetcher.m \
    Sources/Core/TGMessageItem.m \
    -framework Cocoa \
    -framework ImageIO \
    -o "$BUILD_DIR/media_image_loader_probe"

HOME="$TEST_HOME" "$BUILD_DIR/media_image_loader_probe"

echo "== Sticker thumbnail pipeline =="
python3 scripts/test_sticker_thumbnail_pipeline.py

echo "== Media playback speed preferences =="
"$CLANG" \
    "${COMPILE_FLAGS[@]}" \
    Tests/media_playback_preferences_probe.m \
    Sources/Media/TGMediaPlaybackPreferences.m \
    -framework Foundation \
    -o "$BUILD_DIR/media_playback_preferences_probe"
HOME="$TEST_HOME" "$BUILD_DIR/media_playback_preferences_probe"

echo "== Sequential audio playback =="
"$CLANG" \
    "${COMPILE_FLAGS[@]}" \
    Tests/media_playback_sequence_probe.m \
    Sources/Media/TGMediaPlaybackSequence.m \
    Sources/Core/TGMessageItem.m \
    -framework Foundation \
    -o "$BUILD_DIR/media_playback_sequence_probe"
HOME="$TEST_HOME" "$BUILD_DIR/media_playback_sequence_probe"

echo "== Storage cleanup filters =="
"$CLANG" \
    "${COMPILE_FLAGS[@]}" \
    Tests/storage_cleanup_policy_probe.m \
    Sources/Services/TGStorageCleanupPolicy.m \
    -framework Foundation \
    -o "$BUILD_DIR/storage_cleanup_policy_probe"
HOME="$TEST_HOME" "$BUILD_DIR/storage_cleanup_policy_probe"

echo "== Custom emoji descriptors =="
"$CLANG" \
    "${COMPILE_FLAGS[@]}" \
    Tests/custom_emoji_parser_probe.m \
    Sources/Core/TGCustomEmojiParser.m \
    -framework Foundation \
    -o "$BUILD_DIR/custom_emoji_parser_probe"

HOME="$TEST_HOME" "$BUILD_DIR/custom_emoji_parser_probe" Tests/Fixtures/custom_emoji_stickers.json

echo "== Advanced chat folders =="
"$CLANG" \
    "${COMPILE_FLAGS[@]}" \
    Tests/chat_folder_support_probe.m \
    Sources/Core/TGChatFolderSupport.m \
    -framework Foundation \
    -o "$BUILD_DIR/chat_folder_support_probe"

HOME="$TEST_HOME" "$BUILD_DIR/chat_folder_support_probe" Tests/Fixtures/chat_folder_advanced.json

echo "== Core logic probe =="

"$CLANG" \
    "${COMPILE_FLAGS[@]}" \
    Tests/core_logic_probe.m \
    Sources/Core/TGMessageItem.m \
    Sources/Core/TGMessagePollSupport.m \
    Sources/Core/TGOutgoingMessageTextChunker.m \
    Sources/Core/TGCustomEmojiParser.m \
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
