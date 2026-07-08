#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

TDLIB_VERSION="${TDLIB_VERSION:-v1.8.0}"
TDLIB_LABEL="${TDLIB_LABEL:-$TDLIB_VERSION}"
COMPILER_CC="${CC:-}"
COMPILER_CXX="${CXX:-}"
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
PATCH_LEGACY_LINKER=1
PATCH_MAVERICKS_FDOPENDIR=1
PATCH_MAVERICKS_CLOCK_GETTIME=1
PATCH_WEBPAGES_MANAGER_STACK_ADDRESS_WARNING=1

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
  --no-patch-legacy-linker
                          keep TDLib's Apple linker strip flags unchanged
  --no-patch-fdopendir    keep TDLib's fdopendir-based directory walk unchanged
  --no-patch-clock-gettime
                          keep TDLib's clock_gettime debug clock code unchanged
  --no-patch-webpages-warning
                          keep TDLib WebPagesManager lambda warning unchanged
  --allow-unknown-tag     allow sources that cannot prove ${TDLIB_VERSION}
  --allow-snapshot        alias for --allow-unknown-tag for TDLib snapshots
  -h, --help              show this help

Environment:
  CC/CXX                  optional compiler override for snapshot experiments
                          such as /opt/local/bin/clang-mp-17 and clang++-mp-17

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

print_tdjson_candidates() {
    local root="$1"
    find "$root" \( -name '*tdjson*' -o -name 'libtd*.dylib' \) -print | sed -n '1,80p'
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

tdlib_project_version() {
    local source_root="$1"
    awk '
        /project\(TDLib VERSION/ {
            for (i = 1; i <= NF; i++) {
                if ($i == "VERSION" && (i + 1) <= NF) {
                    version = $(i + 1);
                    gsub(/[^0-9.].*/, "", version);
                    print version;
                    exit;
                }
            }
        }
    ' "$source_root/CMakeLists.txt" 2>/dev/null || true
}

tdlib_mtproto_layer() {
    local source_root="$1"
    awk '
        /MTPROTO_LAYER/ {
            for (i = 1; i <= NF; i++) {
                if ($i ~ /^[0-9]+;?$/) {
                    gsub(/;/, "", $i);
                    print $i;
                    exit;
                }
            }
        }
    ' "$source_root/td/telegram/Version.h" 2>/dev/null || true
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

patch_tdlib_for_legacy_linker() {
    local source_root="$1"
    local compiler_file="$source_root/CMake/TdSetUpCompiler.cmake"
    local marker_file="$BUILD_DIR/legacy-linker-patch.txt"

    if [ "$PATCH_LEGACY_LINKER" -ne 1 ]; then
        return 0
    fi

    if [ ! -f "$compiler_file" ]; then
        if [ "$ALLOW_UNKNOWN_TAG" -eq 1 ]; then
            echo "Warning: could not find TDLib compiler setup file; skipping legacy linker patch for snapshot source."
            return 0
        fi
        fail "Could not find TDLib compiler setup file: $compiler_file"
    fi

    if ! grep -q 'set(TD_LINKER_FLAGS "-Wl,-dead_strip")' "$compiler_file"; then
        echo "Warning: TDLib Apple linker strip flags were not found; skipping legacy linker patch."
        return 0
    fi

    cp "$compiler_file" "$compiler_file.telegraphica-backup"
    sed \
        -e 's/set(TD_LINKER_FLAGS "-Wl,-dead_strip")/set(TD_LINKER_FLAGS "") # Telegraphica legacy Xcode 6 linker workaround/' \
        -e 's/set(TD_LINKER_FLAGS "${TD_LINKER_FLAGS},-x,-S")/set(TD_LINKER_FLAGS "${TD_LINKER_FLAGS}") # Telegraphica legacy Xcode 6 linker workaround/' \
        "$compiler_file.telegraphica-backup" > "$compiler_file"
    {
        echo "Patched TDLib Apple linker strip flags for Xcode 6.2 compatibility."
        echo "File: $compiler_file"
        echo "Removed: -Wl,-dead_strip,-x,-S"
    } > "$marker_file"
    echo "Patched TDLib Apple linker strip flags for Xcode 6.2 compatibility."
}

patch_tdlib_for_mavericks_fdopendir() {
    local source_root="$1"
    local path_file="$source_root/tdutils/td/utils/port/path.cpp"
    local marker_file="$BUILD_DIR/mavericks-fdopendir-patch.txt"

    if [ "$PATCH_MAVERICKS_FDOPENDIR" -ne 1 ]; then
        return 0
    fi

    if [ ! -f "$path_file" ]; then
        if [ "$ALLOW_UNKNOWN_TAG" -eq 1 ]; then
            echo "Warning: could not find TDLib path source file; skipping fdopendir patch for snapshot source."
            return 0
        fi
        fail "Could not find TDLib path source file: $path_file"
    fi

    if ! grep -q 'fdopendir(native_fd.fd())' "$path_file"; then
        echo "Warning: TDLib fdopendir call was not found; skipping Mavericks fdopendir patch."
        return 0
    fi

    cp "$path_file" "$path_file.telegraphica-backup"
    perl -0pi -e 's#Result<bool> walk_path_dir\(string &path, FileFd fd, const WalkFunction &func\) \{\n  auto native_fd = fd\.move_as_native_fd\(\);\n  auto \*subdir = fdopendir\(native_fd\.fd\(\)\);\n  if \(subdir == nullptr\) \{\n    return OS_ERROR\("fdopendir"\);\n  \}\n  native_fd\.release\(\);\n  return walk_path_dir\(path, subdir, func\);\n\}#Result<bool> walk_path_dir(string \&path, FileFd fd, const WalkFunction \&func) {\n  fd.close();\n  return walk_path_dir(path, func);\n}#s' "$path_file"

    if grep -q 'fdopendir(native_fd.fd())' "$path_file"; then
        fail "Failed to patch TDLib fdopendir usage in $path_file"
    fi

    {
        echo "Patched TDLib fdopendir directory walk for OS X 10.9 SDK compatibility."
        echo "File: $path_file"
        echo "Replacement: close FileFd and use path-based opendir fallback."
    } > "$marker_file"
    echo "Patched TDLib fdopendir directory walk for OS X 10.9 SDK compatibility."
}

patch_tdlib_for_mavericks_clock_gettime() {
    local source_root="$1"
    local clocks_file="$source_root/tdutils/td/utils/port/Clocks.cpp"
    local marker_file="$BUILD_DIR/mavericks-clock-gettime-patch.txt"

    if [ "$PATCH_MAVERICKS_CLOCK_GETTIME" -ne 1 ]; then
        return 0
    fi

    if [ ! -f "$clocks_file" ]; then
        if [ "$ALLOW_UNKNOWN_TAG" -eq 1 ]; then
            echo "Warning: could not find TDLib clocks source file; skipping clock_gettime patch for snapshot source."
            return 0
        fi
        fail "Could not find TDLib clocks source file: $clocks_file"
    fi

    if ! grep -q 'clockid_t clock_id' "$clocks_file"; then
        echo "Warning: TDLib clock_gettime debug block was not found; skipping Mavericks clock_gettime patch."
        return 0
    fi

    cp "$clocks_file" "$clocks_file.telegraphica-backup"
    perl -0pi -e 's@string result;\n#if TD_PORT_POSIX\n  auto add_clock =@string result;\n#if TD_PORT_POSIX \&\& !defined(__APPLE__)\n  auto add_clock =@' "$clocks_file"

    if ! perl -0ne '$found = /string result;\n#if TD_PORT_POSIX && !defined\(__APPLE__\)\n  auto add_clock =/ ? 1 : 0; END { exit($found ? 0 : 1) }' "$clocks_file"; then
        fail "Failed to patch TDLib clock_gettime debug block in $clocks_file"
    fi

    {
        echo "Patched TDLib clock_gettime debug clock block for OS X 10.9 SDK compatibility."
        echo "File: $clocks_file"
        echo "Replacement: skip POSIX clock_gettime debug enumeration on Apple legacy builds."
    } > "$marker_file"
    echo "Patched TDLib clock_gettime debug clock block for OS X 10.9 SDK compatibility."
}

patch_tdlib_for_webpages_manager_stack_address_warning() {
    local source_root="$1"
    local webpages_file="$source_root/td/telegram/WebPagesManager.cpp"
    local marker_file="$BUILD_DIR/webpages-manager-warning-patch.txt"

    if [ "$PATCH_WEBPAGES_MANAGER_STACK_ADDRESS_WARNING" -ne 1 ]; then
        return 0
    fi

    if [ ! -f "$webpages_file" ]; then
        if [ "$ALLOW_UNKNOWN_TAG" -eq 1 ]; then
            echo "Warning: could not find TDLib WebPagesManager.cpp; skipping stack-address warning patch for snapshot source."
            return 0
        fi
        fail "Could not find TDLib WebPagesManager.cpp: $webpages_file"
    fi

    if ! grep -q 'auto get_map = \[&\](Document::Type document_type) {' "$webpages_file"; then
        echo "Warning: TDLib WebPagesManager get_map lambda was not found; skipping stack-address warning patch."
        return 0
    fi

    cp "$webpages_file" "$webpages_file.telegraphica-backup"
    perl -0pi -e 's/auto get_map = \[\&\]\(Document::Type document_type\) \{/auto get_map = [\&](Document::Type document_type) -> std::unordered_map<int64, FileId> * {/' "$webpages_file"

    if ! grep -q 'auto get_map = \[&\](Document::Type document_type) -> std::unordered_map<int64, FileId> \* {' "$webpages_file"; then
        fail "Failed to patch TDLib WebPagesManager get_map lambda in $webpages_file"
    fi

    {
        echo "Patched TDLib WebPagesManager get_map lambda to silence false return-stack-address warnings."
        echo "File: $webpages_file"
        echo "Replacement: explicit lambda return type std::unordered_map<int64, FileId> *."
    } > "$marker_file"
    echo "Patched TDLib WebPagesManager stack-address warning."
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
        --no-patch-legacy-linker)
            PATCH_LEGACY_LINKER=0
            shift
            ;;
        --no-patch-fdopendir)
            PATCH_MAVERICKS_FDOPENDIR=0
            shift
            ;;
        --no-patch-clock-gettime)
            PATCH_MAVERICKS_CLOCK_GETTIME=0
            shift
            ;;
        --no-patch-webpages-warning)
            PATCH_WEBPAGES_MANAGER_STACK_ADDRESS_WARNING=0
            shift
            ;;
        --allow-unknown-tag|--allow-snapshot)
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
if [ "$PATCH_MAVERICKS_FDOPENDIR" -eq 1 ] || [ "$PATCH_MAVERICKS_CLOCK_GETTIME" -eq 1 ]; then
    require_command perl
fi

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

TDLIB_PROJECT_VERSION="$(tdlib_project_version "$SOURCE_ROOT")"
TDLIB_MTPROTO_LAYER="$(tdlib_mtproto_layer "$SOURCE_ROOT")"
if [ -n "$TDLIB_PROJECT_VERSION" ]; then
    echo "Detected TDLib project version: $TDLIB_PROJECT_VERSION"
fi
if [ -n "$TDLIB_MTPROTO_LAYER" ]; then
    echo "Detected TDLib MTProto layer: $TDLIB_MTPROTO_LAYER"
    if [ "$TDLIB_MTPROTO_LAYER" -lt 170 ]; then
        echo "Warning: this TDLib API layer is old and may be rejected by Telegram login with UPDATE_APP_TO_LOGIN."
    fi
fi

patch_tdlib_for_legacy_linker "$SOURCE_ROOT"
patch_tdlib_for_mavericks_fdopendir "$SOURCE_ROOT"
patch_tdlib_for_mavericks_clock_gettime "$SOURCE_ROOT"
patch_tdlib_for_webpages_manager_stack_address_warning "$SOURCE_ROOT"

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
if [ -n "$COMPILER_CC" ]; then
    CMAKE_ARGS+=("-DCMAKE_C_COMPILER=$COMPILER_CC")
fi
if [ -n "$COMPILER_CXX" ]; then
    CMAKE_ARGS+=("-DCMAKE_CXX_COMPILER=$COMPILER_CXX")
fi
if [ -n "$OPENSSL_ROOT" ]; then
    CMAKE_ARGS+=("-DOPENSSL_ROOT_DIR=$OPENSSL_ROOT")
fi
if [ -n "$ZLIB_ROOT" ]; then
    CMAKE_ARGS+=("-DZLIB_ROOT=$ZLIB_ROOT")
fi

export MACOSX_DEPLOYMENT_TARGET="$DEPLOYMENT_TARGET"

echo "Building TDLib $TDLIB_LABEL tdjson for OS X $DEPLOYMENT_TARGET ($ARCH)."
echo "Source: $SOURCE_ROOT"
echo "Build:  $CONFIGURE_DIR"
echo "Stage:  $STAGE_DIR/Frameworks"
if [ -n "$COMPILER_CC" ]; then
    echo "C compiler:   $COMPILER_CC"
fi
if [ -n "$COMPILER_CXX" ]; then
    echo "C++ compiler: $COMPILER_CXX"
fi

set +e
(
    set -e
    cd "$CONFIGURE_DIR"
    "$CMAKE_BIN" "${CMAKE_ARGS[@]}"
    "$CMAKE_BIN" --build . --target tdjson -- -j "$JOBS"
) 2>&1 | tee "$BUILD_DIR/build.log"
BUILD_STATUS=${PIPESTATUS[0]}
set -e

if [ "$BUILD_STATUS" -ne 0 ]; then
    fail "TDLib build failed. Check $BUILD_DIR/build.log"
fi

TDJSON_BUILT="$(find_tdjson_dylib "$CONFIGURE_DIR" || true)"
if [ -z "$TDJSON_BUILT" ]; then
    echo "Build succeeded, but no libtdjson dylib candidate was found under $CONFIGURE_DIR."
    echo "TDLib-related outputs found under the build directory:"
    print_tdjson_candidates "$CONFIGURE_DIR"
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
