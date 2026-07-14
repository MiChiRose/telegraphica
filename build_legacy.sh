#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

PROJECT="Telegraphica.xcodeproj"
TARGET="Telegraphica"
SCHEME="${TELEGRAPHICA_SCHEME:-$TARGET}"
APP_NAME="Telegraphica.app"
EXECUTABLE_NAME="Telegraphica"
DEPLOYMENT_TARGET="10.9"
ARCH="x86_64"
BUILD_ROOT="build-legacy"
DERIVED_DATA_PATH="$BUILD_ROOT/DerivedData"
DIST_DIR="${TELEGRAPHICA_DIST_DIR:-$PWD/dist}"

if [ -z "${DEVELOPER_DIR:-}" ] && [ -d "/Applications/Xcode_6.2.app/Contents/Developer" ]; then
    export DEVELOPER_DIR="/Applications/Xcode_6.2.app/Contents/Developer"
fi

XCODEBUILD=$(xcrun -f xcodebuild 2>/dev/null || command -v xcodebuild || true)
if [ -z "$XCODEBUILD" ]; then
    echo "xcodebuild was not found."
    exit 1
fi

binary_contains_arch() {
    local binary_path="$1"
    local expected_arch="$2"
    local lipo_output=""

    if command -v lipo >/dev/null 2>&1; then
        lipo_output="$(lipo -archs "$binary_path" 2>/dev/null || true)"
        if [ -z "$lipo_output" ]; then
            lipo_output="$(lipo -info "$binary_path" 2>/dev/null || true)"
        fi
        if [ -n "$lipo_output" ] && echo "$lipo_output" | tr ' :' '\n\n' | grep -qx "$expected_arch"; then
            return 0
        fi
    fi

    file "$binary_path" | grep -q "$expected_arch"
}

PYTHON_BIN=""
if command -v python3 >/dev/null 2>&1; then
    PYTHON_BIN="$(command -v python3)"
elif command -v python >/dev/null 2>&1; then
    PYTHON_BIN="$(command -v python)"
fi

if [ -n "$PYTHON_BIN" ]; then
    "$PYTHON_BIN" scripts/check_legacy_compat.py
else
    echo "Skipping legacy compatibility script: python/python3 was not found."
fi

SDK_NAME="macosx"
if "$XCODEBUILD" -showsdks 2>/dev/null | grep -q "macosx10\.9"; then
    SDK_NAME="macosx10.9"
fi
SDK_ARGS=(-sdk "$SDK_NAME")

scripts/check_media_item_support.sh "$ARCH" "$BUILD_ROOT/Tests/media-item-support" "$SDK_NAME"

INFO_SOURCE="Sources/Info.plist"
APP_VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$INFO_SOURCE" 2>/dev/null || true)"
if [ -z "$APP_VERSION" ]; then
    APP_VERSION="0.1.0"
fi
APP_BUILD="$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$INFO_SOURCE" 2>/dev/null || true)"
if [ -z "$APP_BUILD" ]; then
    APP_BUILD="$APP_VERSION"
fi
DIST_ZIP="$DIST_DIR/Telegraphica_v${APP_VERSION}.zip"

valid_tdlib_config() {
    local config_path="$1"
    local api_id=""
    local api_hash=""

    if [ ! -f "$config_path" ]; then
        return 1
    fi
    api_id="$(/usr/libexec/PlistBuddy -c "Print :api_id" "$config_path" 2>/dev/null || true)"
    api_hash="$(/usr/libexec/PlistBuddy -c "Print :api_hash" "$config_path" 2>/dev/null || true)"
    if ! echo "$api_id" | grep -E -q '^[1-9][0-9]*$'; then
        return 1
    fi
    echo "$api_hash" | grep -E -q '^[[:xdigit:]]{32}$'
}

BUNDLED_TDLIB_CONFIG_SOURCE="${TELEGRAPHICA_BUNDLED_TDLIB_CONFIG_PATH:-}"
if [ -n "$BUNDLED_TDLIB_CONFIG_SOURCE" ] && ! valid_tdlib_config "$BUNDLED_TDLIB_CONFIG_SOURCE"; then
    echo "TELEGRAPHICA_BUNDLED_TDLIB_CONFIG_PATH is missing or does not contain valid api_id and api_hash."
    exit 1
fi

if [ -z "$BUNDLED_TDLIB_CONFIG_SOURCE" ]; then
    for CONFIG_CANDIDATE in \
        "$HOME/Library/Application Support/Telegraphica/tdlib-config.plist" \
        "$BUILD_ROOT/Release/$APP_NAME/Contents/Resources/TelegraphicaTDLibDefaults.plist" \
        "$APP_NAME/Contents/Resources/TelegraphicaTDLibDefaults.plist" \
        "/Applications/$APP_NAME/Contents/Resources/TelegraphicaTDLibDefaults.plist"
    do
        if valid_tdlib_config "$CONFIG_CANDIDATE"; then
            BUNDLED_TDLIB_CONFIG_SOURCE="$CONFIG_CANDIDATE"
            break
        fi
    done
fi

TDJSON_STAGED_PATH=""
BUNDLED_TDLIB_CONFIG_TEMP=""
cleanup_legacy_build_inputs() {
    if [ -n "$TDJSON_STAGED_PATH" ]; then
        rm -f "$TDJSON_STAGED_PATH"
    fi
    if [ -n "$BUNDLED_TDLIB_CONFIG_TEMP" ]; then
        rm -f "$BUNDLED_TDLIB_CONFIG_TEMP"
    fi
}
trap cleanup_legacy_build_inputs EXIT

if [ -n "$BUNDLED_TDLIB_CONFIG_SOURCE" ]; then
    BUNDLED_TDLIB_CONFIG_TEMP="$(mktemp /tmp/telegraphica-tdlib-config.XXXXXX)"
    ditto "$BUNDLED_TDLIB_CONFIG_SOURCE" "$BUNDLED_TDLIB_CONFIG_TEMP"
    chmod 0600 "$BUNDLED_TDLIB_CONFIG_TEMP"
    BUNDLED_TDLIB_CONFIG_SOURCE="$BUNDLED_TDLIB_CONFIG_TEMP"
    echo "Preserved the existing internal Telegram connection configuration."
else
    echo "Warning: no internal Telegram connection configuration was found."
    echo "This development build will not be able to start a new Telegram sign-in."
fi

if [ -n "${TELEGRAPHICA_TDJSON_PATH:-}" ]; then
    if [ ! -f "$TELEGRAPHICA_TDJSON_PATH" ]; then
        echo "TELEGRAPHICA_TDJSON_PATH does not point to a file: $TELEGRAPHICA_TDJSON_PATH"
        exit 1
    fi
    TDJSON_STAGED_PATH="$(mktemp /tmp/telegraphica-tdjson.XXXXXX)"
    ditto "$TELEGRAPHICA_TDJSON_PATH" "$TDJSON_STAGED_PATH"
    chmod 0644 "$TDJSON_STAGED_PATH"
    TELEGRAPHICA_TDJSON_PATH="$TDJSON_STAGED_PATH"
    echo "Staged TDLib JSON library for rebuild."
fi

rm -rf "$BUILD_ROOT" "$APP_NAME"

WEBP_BUILD_DIR="$BUILD_ROOT/Vendor/libwebp"
scripts/build_webp_legacy.sh "$ARCH" "$WEBP_BUILD_DIR"
WEBP_STATIC_LIBRARY="$PWD/$WEBP_BUILD_DIR/libwebpdecoder.a"
if [ ! -f "$WEBP_STATIC_LIBRARY" ]; then
    echo "WebP decoder library was not produced: $WEBP_STATIC_LIBRARY"
    exit 1
fi

RLOTTIE_BUILD_DIR="$BUILD_ROOT/Vendor/rlottie"
scripts/build_rlottie_legacy.sh "$ARCH" "$RLOTTIE_BUILD_DIR" "$SDK_NAME"
RLOTTIE_STATIC_LIBRARY="$PWD/$RLOTTIE_BUILD_DIR/librlottie.a"
if [ ! -f "$RLOTTIE_STATIC_LIBRARY" ]; then
    echo "rlottie library was not produced: $RLOTTIE_STATIC_LIBRARY"
    exit 1
fi
scripts/check_tgs_legacy.sh "$ARCH" "$RLOTTIE_BUILD_DIR" "$SDK_NAME"

COMMON_SETTINGS=(
    "ARCHS=$ARCH"
    "VALID_ARCHS=$ARCH"
    "SDKROOT=$SDK_NAME"
    "ONLY_ACTIVE_ARCH=NO"
    "MACOSX_DEPLOYMENT_TARGET=$DEPLOYMENT_TARGET"
    "CLANG_ENABLE_OBJC_ARC=NO"
    "CLANG_LINK_OBJC_RUNTIME=NO"
    "ENABLE_CODE_COVERAGE=NO"
    "CLANG_ENABLE_CODE_COVERAGE=NO"
    "CLANG_COVERAGE_MAPPING=NO"
    "CLANG_MODULE_CACHE_PATH=$BUILD_ROOT/ModuleCache.noindex"
    "CLANG_PROFILE_GENERATE=NO"
    "CLANG_INSTRUMENT_FOR_OPTIMIZATION_PROFILING=NO"
    "GCC_PROFILE_GENERATE=NO"
    "GCC_GENERATE_TEST_COVERAGE_FILES=NO"
    "GCC_INSTRUMENT_PROGRAM_FLOW_ARCS=NO"
    "CODE_SIGNING_ALLOWED=NO"
    "CODE_SIGNING_REQUIRED=NO"
    "CODE_SIGN_IDENTITY="
    "HEADER_SEARCH_PATHS=$PWD/Vendor/libwebp/src $PWD/Vendor/rlottie/inc"
    "OTHER_LDFLAGS=\$(inherited) $WEBP_STATIC_LIBRARY $RLOTTIE_STATIC_LIBRARY -lc++ -lz"
    "SYMROOT=$BUILD_ROOT"
    "OBJROOT=$BUILD_ROOT/Intermediates"
    "DSTROOT=$BUILD_ROOT/Install"
)

echo "Building Telegraphica for OS X $DEPLOYMENT_TARGET ($ARCH)."
echo "Using $("$XCODEBUILD" -version | tr '\n' ' ') with SDK $SDK_NAME."

BUILD_SELECTOR=(-scheme "$SCHEME")
if ! "$XCODEBUILD" -list -project "$PROJECT" 2>/dev/null | sed 's/^[[:space:]]*//' | grep -Fx -q "$SCHEME"; then
    echo "Scheme '$SCHEME' was not found; falling back to target '$TARGET'."
    BUILD_SELECTOR=(-target "$TARGET")
fi

set +e
"$XCODEBUILD" \
    -project "$PROJECT" \
    "${BUILD_SELECTOR[@]}" \
    -configuration Release \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    "${SDK_ARGS[@]}" \
    -arch "$ARCH" \
    build \
    "${COMMON_SETTINGS[@]}" 2>&1 | tee build.log
BUILD_STATUS=${PIPESTATUS[0]}
set -e

if [ "$BUILD_STATUS" -ne 0 ]; then
    echo "Build failed. Check build.log."
    exit 1
fi

APP_PATH="$BUILD_ROOT/Release/$APP_NAME"
if [ ! -d "$APP_PATH" ]; then
    echo "Build succeeded, but $APP_PATH was not produced."
    exit 1
fi

ditto "$APP_PATH" "$APP_NAME"

INFO_PLIST="$APP_NAME/Contents/Info.plist"
BINARY_PATH="$APP_NAME/Contents/MacOS/$EXECUTABLE_NAME"

/usr/libexec/PlistBuddy -c "Set :LSMinimumSystemVersion $DEPLOYMENT_TARGET" "$INFO_PLIST" 2>/dev/null || \
    /usr/libexec/PlistBuddy -c "Add :LSMinimumSystemVersion string $DEPLOYMENT_TARGET" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $APP_VERSION" "$INFO_PLIST" 2>/dev/null || \
    /usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string $APP_VERSION" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $APP_BUILD" "$INFO_PLIST" 2>/dev/null || \
    /usr/libexec/PlistBuddy -c "Add :CFBundleVersion string $APP_BUILD" "$INFO_PLIST"

MIN_PLIST=$(/usr/libexec/PlistBuddy -c "Print :LSMinimumSystemVersion" "$INFO_PLIST")
if [ "$MIN_PLIST" != "$DEPLOYMENT_TARGET" ]; then
    echo "Info.plist minimum system version is $MIN_PLIST, expected $DEPLOYMENT_TARGET."
    exit 1
fi

if ! file "$BINARY_PATH" | grep -q "$ARCH"; then
    echo "Binary does not appear to contain $ARCH:"
    file "$BINARY_PATH"
    exit 1
fi

if ! binary_contains_arch "$BINARY_PATH" "$ARCH"; then
    echo "Release binary does not appear to contain $ARCH."
    file "$BINARY_PATH"
    if command -v lipo >/dev/null 2>&1; then
        lipo -info "$BINARY_PATH" 2>/dev/null || true
    fi
    exit 1
fi

MIN_MACHO=$(otool -l "$BINARY_PATH" | awk '/LC_VERSION_MIN_MACOSX/{found=1} found && /version /{print $2; exit}')
if [ -z "$MIN_MACHO" ]; then
    if otool -l "$BINARY_PATH" | grep -q "LC_BUILD_VERSION"; then
        echo "Binary uses LC_BUILD_VERSION instead of LC_VERSION_MIN_MACOSX; verify on Xcode 6.2 before release."
        exit 1
    fi
else
    if [ "$MIN_MACHO" != "$DEPLOYMENT_TARGET" ]; then
        echo "Mach-O minimum system version is $MIN_MACHO, expected $DEPLOYMENT_TARGET."
        exit 1
    fi
fi

if otool -l "$BINARY_PATH" | grep -E -q "__LLVM|__llvm|__llvm_prf"; then
    echo "Release binary contains LLVM/profile sections."
    exit 1
fi

if strings -a "$BINARY_PATH" | grep -E -q "__llvm_prf|libclang_rt\\.profile|default\\.profraw"; then
    echo "Release binary contains LLVM profile runtime references."
    exit 1
fi

if [ -n "${TELEGRAPHICA_TDJSON_PATH:-}" ]; then
    if [ ! -f "$TELEGRAPHICA_TDJSON_PATH" ]; then
        echo "TELEGRAPHICA_TDJSON_PATH does not point to a file: $TELEGRAPHICA_TDJSON_PATH"
        exit 1
    fi

    FRAMEWORKS_DIR="$APP_NAME/Contents/Frameworks"
    TDJSON_DEST="$FRAMEWORKS_DIR/libtdjson.dylib"

    mkdir -p "$FRAMEWORKS_DIR"
    ditto "$TELEGRAPHICA_TDJSON_PATH" "$TDJSON_DEST"
    TELEGRAPHICA_REQUIRE_PORTABLE_TDJSON=1 scripts/check_tdjson_legacy.sh "$TDJSON_DEST"
fi

if [ -n "$BUNDLED_TDLIB_CONFIG_SOURCE" ]; then
    API_ID="$(/usr/libexec/PlistBuddy -c "Print :api_id" "$BUNDLED_TDLIB_CONFIG_SOURCE" 2>/dev/null || true)"
    API_HASH="$(/usr/libexec/PlistBuddy -c "Print :api_hash" "$BUNDLED_TDLIB_CONFIG_SOURCE" 2>/dev/null || true)"
    if [ -z "$API_ID" ] || ! echo "$API_HASH" | grep -E -q '^[[:xdigit:]]{32}$'; then
        echo "Bundled TDLib config must contain api_id and api_hash."
        exit 1
    fi
    if ! echo "$API_ID" | grep -E -q '^[0-9]+$'; then
        echo "Bundled TDLib config api_id must be numeric."
        exit 1
    fi

    RESOURCES_DIR="$APP_NAME/Contents/Resources"
    BUNDLED_CONFIG_DEST="$RESOURCES_DIR/TelegraphicaTDLibDefaults.plist"
    mkdir -p "$RESOURCES_DIR"
    rm -f "$BUNDLED_CONFIG_DEST"
    /usr/libexec/PlistBuddy -c "Add :api_id integer $API_ID" "$BUNDLED_CONFIG_DEST"
    /usr/libexec/PlistBuddy -c "Add :api_hash string $API_HASH" "$BUNDLED_CONFIG_DEST"
    /usr/libexec/PlistBuddy -c "Add :tdlib_parameters_schema string auto" "$BUNDLED_CONFIG_DEST"
    /usr/libexec/PlistBuddy -c "Add :use_test_dc bool false" "$BUNDLED_CONFIG_DEST"
    chmod 0644 "$BUNDLED_CONFIG_DEST"
    echo "Bundled sanitized TDLib app config: $BUNDLED_CONFIG_DEST"
fi

xattr -cr "$APP_NAME" 2>/dev/null || true
if command -v codesign >/dev/null 2>&1; then
    codesign --force --deep --sign - "$APP_NAME"
    codesign --verify --deep "$APP_NAME"
fi

ditto "$APP_NAME" "$APP_PATH"

mkdir -p "$DIST_DIR"
rm -f "$DIST_ZIP"
ditto -c -k --norsrc --keepParent "$APP_NAME" "$DIST_ZIP"
rm -rf "$APP_NAME"

echo "Created $(basename "$DIST_ZIP") at $DIST_ZIP"
