#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

TDLIB_VERSION="${TDLIB_VERSION:-v1.8.0}"
TDLIB_LABEL="${TDLIB_LABEL:-$TDLIB_VERSION}"
COMPILER_CC="${CC:-}"
COMPILER_CXX="${CXX:-}"
ARCH="${TELEGRAPHICA_ARCH:-x86_64}"
DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET:-10.8}"
BUILD_DIR="$ROOT_DIR/build-tdlib-legacy"
INSTALL_DIR=""
STAGE_DIR=""
SOURCE_PATH=""
ARCHIVE_PATH=""
OPENSSL_ROOT="${TDLIB_OPENSSL_ROOT:-}"
ZLIB_ROOT="${TDLIB_ZLIB_ROOT:-}"
CMAKE_BIN="${CMAKE:-cmake}"
CMAKE_MAKE_PROGRAM="${CMAKE_MAKE_PROGRAM:-/usr/bin/make}"
GPERF_BIN="${GPERF:-gperf}"
TDLIB_RELEASE_C_FLAGS="${TDLIB_RELEASE_C_FLAGS:--O0 -fno-vectorize -fno-slp-vectorize -DNDEBUG}"
TDLIB_RELEASE_CXX_FLAGS="${TDLIB_RELEASE_CXX_FLAGS:--O0 -fno-vectorize -fno-slp-vectorize -DNDEBUG}"
JOBS=""
CLEAN=0
ALLOW_UNKNOWN_TAG=0
PATCH_LEGACY_LINKER=1
PATCH_MAVERICKS_FDOPENDIR=1
PATCH_MAVERICKS_CLOCK_GETTIME=1
PATCH_WEBPAGES_MANAGER_STACK_ADDRESS_WARNING=1
PATCH_XCODE5_SCOPE_EXIT_HEAP_GUARD=1
PATCH_XCODE5_FILEFD_SCOPE_EXIT=1
PATCH_XCODE5_STATUS_SCOPE_EXIT=1
PATCH_XCODE5_IPADDRESS_SCOPE_EXIT=1
PATCH_XCODE5_STDSTREAMS_SCOPE_EXIT=1
PATCH_XCODE5_ORDERED_EVENTS_RESIZE=1
PATCH_LOGEVENT_PARSER_STATUS=1
PATCH_NETSTATS_PARSE_GUARD=1
PATCH_THEME_CHAT_THEMES_PARSE_GUARD=1
PATCH_MESSAGES_NOTIFICATION_SETTINGS_PARSE_GUARD=1
PATCH_STICKERS_DATABASE_PARSE_GUARD=1
PATCH_CONTACTS_USER_PARSE_GUARD=1
PATCH_CONTACTS_LIST_PARSE_GUARD=1
PATCH_CONTACTS_CHAT_PARSE_GUARD=1
PATCH_CONTACTS_CHANNEL_PARSE_GUARD=1
PATCH_CONTACTS_SECRET_CHAT_PARSE_GUARD=1

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
        -e 's/add_cxx_compiler_flag("-Wodr")/# Telegraphica legacy Xcode workaround: skip -Wodr/' \
        -e 's/add_cxx_compiler_flag("-flto-odr-type-merging")/# Telegraphica legacy Xcode workaround: skip -flto-odr-type-merging/' \
        "$compiler_file.telegraphica-backup" > "$compiler_file"
    {
        echo "Patched TDLib Apple linker strip flags for Xcode 6.2 compatibility."
        echo "File: $compiler_file"
        echo "Removed: -Wl,-dead_strip,-x,-S"
        echo "Removed: -Wodr and -flto-odr-type-merging"
    } > "$marker_file"
    echo "Patched TDLib Apple linker/ODR flags for legacy Xcode compatibility."
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

patch_tdlib_for_xcode5_filefd_scope_exit() {
    local source_root="$1"
    local filefd_file="$source_root/tdutils/td/utils/port/FileFd.cpp"
    local marker_file="$BUILD_DIR/xcode5-filefd-scope-exit-patch.txt"

    if [ "$PATCH_XCODE5_FILEFD_SCOPE_EXIT" -ne 1 ]; then
        return 0
    fi

    if [ ! -f "$filefd_file" ]; then
        if [ "$ALLOW_UNKNOWN_TAG" -eq 1 ]; then
            echo "Warning: could not find TDLib FileFd.cpp; skipping Xcode 5 FileFd::lock patch for snapshot source."
            return 0
        fi
        fail "Could not find TDLib FileFd.cpp: $filefd_file"
    fi

    if ! grep -q 'SCOPE_EXIT {' "$filefd_file" || ! grep -q 'Status FileFd::lock' "$filefd_file"; then
        echo "Warning: TDLib FileFd::lock SCOPE_EXIT block was not found; skipping Xcode 5 FileFd patch."
        return 0
    fi

    cp "$filefd_file" "$filefd_file.telegraphica-xcode5-backup"
    perl -0pi -e 's@  SCOPE_EXIT \{\n    if \(need_local_unlock\) \{\n      remove_local_lock\(path\);\n    \}\n  \};\n@  // Telegraphica legacy Xcode workaround: AppleClang 5.1.1 crashes while\n  // generating FileFd::lock with SCOPE_EXIT; keep the same cleanup explicit.\n@s' "$filefd_file"
    perl -0pi -e 's@        return OS_ERROR\(PSLICE\(\) << "Can'"'"'t lock file \\"" << path\n                                 << "\\", because it is already in use; check for another program instance running"\);@        if (need_local_unlock) {\n          remove_local_lock(path);\n        }\n        return OS_ERROR(PSLICE() << "Can'"'"'t lock file \\"" << path\n                                 << "\\", because it is already in use; check for another program instance running");@s' "$filefd_file"
    perl -0pi -e 's@      return OS_ERROR\("Can'"'"'t lock file"\);@      if (need_local_unlock) {\n        remove_local_lock(path);\n      }\n      return OS_ERROR("Can'"'"'t lock file");@' "$filefd_file"
    perl -0pi -e 's@  if \(flags == LockFlags::Write\) \{\n    need_local_unlock = false;\n  \}\n  return Status::OK\(\);@  if (flags == LockFlags::Write) {\n    need_local_unlock = false;\n  }\n  if (need_local_unlock) {\n    remove_local_lock(path);\n  }\n  return Status::OK();@' "$filefd_file"

    if grep -q 'SCOPE_EXIT {' "$filefd_file"; then
        fail "Failed to patch TDLib FileFd::lock SCOPE_EXIT block in $filefd_file"
    fi

    {
        echo "Patched TDLib FileFd::lock SCOPE_EXIT for AppleClang 5.1.1 compatibility."
        echo "File: $filefd_file"
        echo "Replacement: explicit local-lock cleanup before error/success returns."
    } > "$marker_file"
    echo "Patched TDLib FileFd::lock SCOPE_EXIT for Xcode 5.1.1 compatibility."
}

patch_tdlib_for_xcode5_scope_exit_heap_guard() {
    local source_root="$1"
    local scope_guard_file="$source_root/tdutils/td/utils/ScopeGuard.h"
    local marker_file="$BUILD_DIR/xcode5-scope-exit-heap-guard-patch.txt"

    if [ "$PATCH_XCODE5_SCOPE_EXIT_HEAP_GUARD" -ne 1 ]; then
        return 0
    fi

    if [ ! -f "$scope_guard_file" ]; then
        if [ "$ALLOW_UNKNOWN_TAG" -eq 1 ]; then
            echo "Warning: could not find TDLib ScopeGuard.h; skipping Xcode 5 SCOPE_EXIT heap guard patch."
            return 0
        fi
        fail "Could not find TDLib ScopeGuard.h: $scope_guard_file"
    fi

    if ! grep -q '#define SCOPE_EXIT auto TD_CONCAT(SCOPE_EXIT_VAR_, __LINE__) = ::td::ScopeExit() + \[&\]' "$scope_guard_file"; then
        echo "Warning: TDLib SCOPE_EXIT macro shape was not found; skipping Xcode 5 heap guard patch."
        return 0
    fi

    cp "$scope_guard_file" "$scope_guard_file.telegraphica-xcode5-backup"
    perl -0pi -e 's@enum class ScopeExit \{\};\ntemplate <class FunctionT>\nauto operator\+\(ScopeExit, FunctionT &&func\) \{\n  return LambdaGuard<std::decay_t<FunctionT>>\(std::forward<FunctionT>\(func\)\);\n\}\n@enum class ScopeExit {};\nenum class ScopeExitHeap {};\ntemplate <class FunctionT>\nLambdaGuard<typename std::decay<FunctionT>::type> operator+(ScopeExit, FunctionT &&func) {\n  return LambdaGuard<typename std::decay<FunctionT>::type>(std::forward<FunctionT>(func));\n}\ntemplate <class FunctionT>\nunique_ptr<Guard> operator+(ScopeExitHeap, FunctionT &&func) {\n  return create_lambda_guard(std::forward<FunctionT>(func));\n}\n@' "$scope_guard_file"
    perl -0pi -e 's@#define SCOPE_EXIT auto TD_CONCAT\(SCOPE_EXIT_VAR_, __LINE__\) = ::td::ScopeExit\(\) \+ \[\&\]@#define SCOPE_EXIT auto TD_CONCAT(SCOPE_EXIT_VAR_, __LINE__) = ::td::ScopeExitHeap() + [&]@' "$scope_guard_file"

    if ! grep -q '#define SCOPE_EXIT auto TD_CONCAT(SCOPE_EXIT_VAR_, __LINE__) = ::td::ScopeExitHeap() + \[&\]' "$scope_guard_file"; then
        fail "Failed to patch TDLib SCOPE_EXIT macro in $scope_guard_file"
    fi

    {
        echo "Patched TDLib SCOPE_EXIT macro for AppleClang 5.1.1 compatibility."
        echo "File: $scope_guard_file"
        echo "Replacement: heap-backed Guard via create_lambda_guard."
    } > "$marker_file"
    echo "Patched TDLib SCOPE_EXIT macro for Xcode 5.1.1 compatibility."
}

patch_tdlib_for_xcode5_status_scope_exit() {
    local source_root="$1"
    local status_file="$source_root/tdutils/td/utils/Status.h"
    local marker_file="$BUILD_DIR/xcode5-status-scope-exit-patch.txt"

    if [ "$PATCH_XCODE5_STATUS_SCOPE_EXIT" -ne 1 ]; then
        return 0
    fi

    if [ ! -f "$status_file" ]; then
        if [ "$ALLOW_UNKNOWN_TAG" -eq 1 ]; then
            echo "Warning: could not find TDLib Status.h; skipping Xcode 5 Result<T> status patch for snapshot source."
            return 0
        fi
        fail "Could not find TDLib Status.h: $status_file"
    fi

    if ! grep -q 'Status move_as_error()' "$status_file" || ! grep -q 'SCOPE_EXIT {' "$status_file"; then
        echo "Warning: TDLib Result<T> SCOPE_EXIT methods were not found; skipping Xcode 5 Status patch."
        return 0
    fi

    cp "$status_file" "$status_file.telegraphica-xcode5-backup"
    perl -0pi -e 's@  Status move_as_error\(\) TD_WARN_UNUSED_RESULT \{\n    CHECK\(status_\.is_error\(\)\);\n    SCOPE_EXIT \{\n      status_ = Status::Error<-4>\(\);\n    \};\n    return std::move\(status_\);\n  \}\n  Status move_as_error_prefix\(Slice prefix\) TD_WARN_UNUSED_RESULT \{\n    SCOPE_EXIT \{\n      status_ = Status::Error<-5>\(\);\n    \};\n    return status_\.move_as_error_prefix\(prefix\);\n  \}\n  Status move_as_error_prefix\(const Status &prefix\) TD_WARN_UNUSED_RESULT \{\n    SCOPE_EXIT \{\n      status_ = Status::Error<-6>\(\);\n    \};\n    return status_\.move_as_error_prefix\(prefix\);\n  \}\n  Status move_as_error_suffix\(Slice suffix\) TD_WARN_UNUSED_RESULT \{\n    SCOPE_EXIT \{\n      status_ = Status::Error<-7>\(\);\n    \};\n    return status_\.move_as_error_suffix\(suffix\);\n  \}@  Status move_as_error() TD_WARN_UNUSED_RESULT {\n    CHECK(status_.is_error());\n    Status result = std::move(status_);\n    status_ = Status::Error<-4>();\n    return result;\n  }\n  Status move_as_error_prefix(Slice prefix) TD_WARN_UNUSED_RESULT {\n    Status result = status_.move_as_error_prefix(prefix);\n    status_ = Status::Error<-5>();\n    return result;\n  }\n  Status move_as_error_prefix(const Status &prefix) TD_WARN_UNUSED_RESULT {\n    Status result = status_.move_as_error_prefix(prefix);\n    status_ = Status::Error<-6>();\n    return result;\n  }\n  Status move_as_error_suffix(Slice suffix) TD_WARN_UNUSED_RESULT {\n    Status result = status_.move_as_error_suffix(suffix);\n    status_ = Status::Error<-7>();\n    return result;\n  }@s' "$status_file"

    if ! grep -q 'Status result = std::move(status_);' "$status_file"; then
        fail "Failed to patch TDLib Result<T> SCOPE_EXIT methods in $status_file"
    fi

    {
        echo "Patched TDLib Result<T> SCOPE_EXIT methods for AppleClang 5.1.1 compatibility."
        echo "File: $status_file"
        echo "Replacement: explicit status reset after constructing return value."
    } > "$marker_file"
    echo "Patched TDLib Result<T> SCOPE_EXIT methods for Xcode 5.1.1 compatibility."
}

patch_tdlib_for_xcode5_ipaddress_scope_exit() {
    local source_root="$1"
    local ipaddress_file="$source_root/tdutils/td/utils/port/IPAddress.cpp"
    local marker_file="$BUILD_DIR/xcode5-ipaddress-scope-exit-patch.txt"

    if [ "$PATCH_XCODE5_IPADDRESS_SCOPE_EXIT" -ne 1 ]; then
        return 0
    fi

    if [ ! -f "$ipaddress_file" ]; then
        if [ "$ALLOW_UNKNOWN_TAG" -eq 1 ]; then
            echo "Warning: could not find TDLib IPAddress.cpp; skipping Xcode 5 IPAddress patch for snapshot source."
            return 0
        fi
        fail "Could not find TDLib IPAddress.cpp: $ipaddress_file"
    fi

    if ! grep -q 'freeaddrinfo(info)' "$ipaddress_file" || ! grep -q 'SCOPE_EXIT {' "$ipaddress_file"; then
        echo "Warning: TDLib IPAddress::init_host_port SCOPE_EXIT block was not found; skipping Xcode 5 IPAddress patch."
        return 0
    fi

    cp "$ipaddress_file" "$ipaddress_file.telegraphica-xcode5-backup"
    perl -0pi -e 's@  SCOPE_EXIT \{\n    freeaddrinfo\(info\);\n  \};\n@  // Telegraphica legacy Xcode workaround: AppleClang 5.1.1 crashes while\n  // generating this SCOPE_EXIT; keep the same cleanup explicit.\n@s' "$ipaddress_file"
    perl -0pi -e 's@  if \(best_info == nullptr\) \{\n    return Status::Error\("Failed to find IPv4/IPv6 address"\);\n  \}\n  return init_sockaddr\(best_info->ai_addr, narrow_cast<socklen_t>\(best_info->ai_addrlen\)\);@  if (best_info == nullptr) {\n    freeaddrinfo(info);\n    return Status::Error("Failed to find IPv4/IPv6 address");\n  }\n  auto status = init_sockaddr(best_info->ai_addr, narrow_cast<socklen_t>(best_info->ai_addrlen));\n  freeaddrinfo(info);\n  return status;@' "$ipaddress_file"

    if grep -q 'SCOPE_EXIT {' "$ipaddress_file"; then
        fail "Failed to patch TDLib IPAddress::init_host_port SCOPE_EXIT block in $ipaddress_file"
    fi

    {
        echo "Patched TDLib IPAddress::init_host_port SCOPE_EXIT for AppleClang 5.1.1 compatibility."
        echo "File: $ipaddress_file"
        echo "Replacement: explicit freeaddrinfo cleanup before returns."
    } > "$marker_file"
    echo "Patched TDLib IPAddress::init_host_port SCOPE_EXIT for Xcode 5.1.1 compatibility."
}

patch_tdlib_for_xcode5_stdstreams_scope_exit() {
    local source_root="$1"
    local stdstreams_file="$source_root/tdutils/td/utils/port/StdStreams.cpp"
    local marker_file="$BUILD_DIR/xcode5-stdstreams-scope-exit-patch.txt"

    if [ "$PATCH_XCODE5_STDSTREAMS_SCOPE_EXIT" -ne 1 ]; then
        return 0
    fi

    if [ ! -f "$stdstreams_file" ]; then
        if [ "$ALLOW_UNKNOWN_TAG" -eq 1 ]; then
            echo "Warning: could not find TDLib StdStreams.cpp; skipping Xcode 5 StdStreams patch for snapshot source."
            return 0
        fi
        fail "Could not find TDLib StdStreams.cpp: $stdstreams_file"
    fi

    if ! grep -q 'static auto guard = ScopeExit() + \[&\]' "$stdstreams_file"; then
        echo "Warning: TDLib StdStreams ScopeExit guard was not found; skipping Xcode 5 StdStreams patch."
        return 0
    fi

    cp "$stdstreams_file" "$stdstreams_file.telegraphica-xcode5-backup"
    perl -0pi -e 's@static auto guard = ScopeExit\(\) \+ \[\&\] \{\n    result\.move_as_native_fd\(\)\.release\(\);\n  \};@static auto guard = create_lambda_guard([&] {\n    result.move_as_native_fd().release();\n  });@g' "$stdstreams_file"

    if grep -q 'static auto guard = ScopeExit() + \[&\]' "$stdstreams_file"; then
        fail "Failed to patch TDLib StdStreams ScopeExit guards in $stdstreams_file"
    fi

    {
        echo "Patched TDLib StdStreams ScopeExit guards for AppleClang 5.1.1 compatibility."
        echo "File: $stdstreams_file"
        echo "Replacement: heap-backed create_lambda_guard for static guards."
    } > "$marker_file"
    echo "Patched TDLib StdStreams ScopeExit guards for Xcode 5.1.1 compatibility."
}

patch_tdlib_for_xcode5_ordered_events_resize() {
    local source_root="$1"
    local ordered_events_file="$source_root/tdutils/td/utils/OrderedEventsProcessor.h"
    local marker_file="$BUILD_DIR/xcode5-ordered-events-resize-patch.txt"

    if [ "$PATCH_XCODE5_ORDERED_EVENTS_RESIZE" -ne 1 ]; then
        return 0
    fi

    if [ ! -f "$ordered_events_file" ]; then
        if [ "$ALLOW_UNKNOWN_TAG" -eq 1 ]; then
            echo "Warning: could not find TDLib OrderedEventsProcessor.h; skipping Xcode 5 resize patch."
            return 0
        fi
        fail "Could not find TDLib OrderedEventsProcessor.h: $ordered_events_file"
    fi

    if ! grep -q 'data_array_\.resize(need_size);' "$ordered_events_file"; then
        echo "Warning: TDLib OrderedEventsProcessor resize call was not found; skipping Xcode 5 resize patch."
        return 0
    fi

    cp "$ordered_events_file" "$ordered_events_file.telegraphica-xcode5-backup"
    perl -0pi -e 's@#include <utility>@#include <deque>\n#include <utility>@' "$ordered_events_file"
    perl -0pi -e 's@    \*this = OrderedEventsProcessor\(\);@    data_array_.clear();\n    offset_ = 1;\n    begin_ = 1;\n    end_ = 1;@g' "$ordered_events_file"
    perl -0pi -e 's@      // try_compactify\n      auto begin_pos = static_cast<size_t>\(begin_ - offset_\);\n      if \(begin_pos > 5 && begin_pos \* 2 > data_array_\.size\(\)\) \{\n        data_array_\.erase\(data_array_\.begin\(\), data_array_\.begin\(\) \+ begin_pos\);\n        offset_ = begin_;\n      \}@      // Telegraphica legacy Xcode workaround: AppleClang 5.1.1 libc++\n      // cannot compact containers that store move-only DataT values here.@' "$ordered_events_file"
    perl -0pi -e 's@      if \(data_array_\.size\(\) < need_size\) \{\n        data_array_\.resize\(need_size\);\n      \}@      while (data_array_.size() < need_size) {\n        data_array_.emplace_back();\n      }@' "$ordered_events_file"
    perl -0pi -e 's@std::vector<std::pair<DataT, bool>> data_array_;@std::deque<std::pair<DataT, bool>> data_array_;@' "$ordered_events_file"

    if grep -q 'data_array_\.resize(need_size);' "$ordered_events_file"; then
        fail "Failed to patch TDLib OrderedEventsProcessor resize call in $ordered_events_file"
    fi
    if grep -q 'data_array_\.erase' "$ordered_events_file"; then
        fail "Failed to patch TDLib OrderedEventsProcessor erase compaction in $ordered_events_file"
    fi
    if ! grep -q 'std::deque<std::pair<DataT, bool>> data_array_;' "$ordered_events_file"; then
        fail "Failed to patch TDLib OrderedEventsProcessor container type in $ordered_events_file"
    fi

    {
        echo "Patched TDLib OrderedEventsProcessor storage for AppleClang/Xcode 5 libc++ compatibility."
        echo "File: $ordered_events_file"
        echo "Replacement: deque storage, no erase compaction, and emplace_back loop avoid moving copy-disabled DataT values."
    } > "$marker_file"
    echo "Patched TDLib OrderedEventsProcessor storage for Xcode 5 libc++ compatibility."
}

patch_tdlib_for_logevent_parser_status() {
    local source_root="$1"
    local logevent_file="$source_root/td/telegram/logevent/LogEvent.h"
    local marker_file="$BUILD_DIR/logevent-parser-status-patch.txt"

    if [ "$PATCH_LOGEVENT_PARSER_STATUS" -ne 1 ]; then
        return 0
    fi

    if [ ! -f "$logevent_file" ]; then
        if [ "$ALLOW_UNKNOWN_TAG" -eq 1 ]; then
            echo "Warning: could not find TDLib LogEvent.h; skipping nonfatal log-event parser patch."
            return 0
        fi
        fail "Could not find TDLib LogEvent.h: $logevent_file"
    fi

    if ! grep -q 'LOG_CHECK(version() < static_cast<int32>(Version::Next)) << "Wrong version " << version();' "$logevent_file"; then
        echo "Warning: TDLib LogEventParser fatal version check was not found; skipping nonfatal log-event parser patch."
        return 0
    fi

    cp "$logevent_file" "$logevent_file.telegraphica-logevent-backup"
    perl -0pi -e 's@  explicit LogEventParser\(Slice data\) : WithVersion<WithContext<TlParser, Global \*>>\(data\) \{\n    set_version\(fetch_int\(\)\);\n    LOG_CHECK\(version\(\) < static_cast<int32>\(Version::Next\)\) << "Wrong version " << version\(\);\n    set_context\(G\(\)\);\n  \}@  explicit LogEventParser(Slice data) : WithVersion<WithContext<TlParser, Global *>>(data) {\n    if (!can_prefetch_int()) {\n      set_version(-1);\n      set_error("Not enough data to read log event version");\n      set_context(G());\n      return;\n    }\n    set_version(fetch_int());\n    if (version() < 0 || version() >= static_cast<int32>(Version::Next)) {\n      set_error("Wrong log event version");\n      set_context(G());\n      return;\n    }\n    set_context(G());\n  }@' "$logevent_file"
    perl -0pi -e 's@Status log_event_parse\(T &data, Slice slice\) \{\n  LogEventParser parser\(slice\);\n  parse\(data, parser\);\n  parser\.fetch_end\(\);\n  return parser\.get_status\(\);\n\}@Status log_event_parse(T &data, Slice slice) {\n  LogEventParser parser(slice);\n  auto parser_status = parser.get_status();\n  if (parser_status.is_error()) {\n    return parser_status.move_as_error();\n  }\n  parse(data, parser);\n  parser.fetch_end();\n  return parser.get_status();\n}@' "$logevent_file"

    if grep -q 'LOG_CHECK(version() < static_cast<int32>(Version::Next)) << "Wrong version " << version();' "$logevent_file"; then
        fail "Failed to patch TDLib LogEventParser fatal version check in $logevent_file"
    fi
    if ! grep -q 'Not enough data to read log event version' "$logevent_file"; then
        fail "Failed to add TDLib LogEventParser status guard in $logevent_file"
    fi
    if ! grep -q 'parser_status.move_as_error()' "$logevent_file"; then
        fail "Failed to add TDLib log_event_parse early status return in $logevent_file"
    fi

    {
        echo "Patched TDLib LogEventParser to report invalid versions as Status errors."
        echo "File: $logevent_file"
        echo "Replacement: no fatal LOG_CHECK before callers can handle parser status."
    } > "$marker_file"
    echo "Patched TDLib LogEventParser invalid-version handling."
}

patch_tdlib_for_netstats_parse_guard() {
    local source_root="$1"
    local netstats_file="$source_root/td/telegram/net/NetStatsManager.cpp"
    local marker_file="$BUILD_DIR/netstats-parse-guard-patch.txt"

    if [ "$PATCH_NETSTATS_PARSE_GUARD" -ne 1 ]; then
        return 0
    fi

    if [ ! -f "$netstats_file" ]; then
        if [ "$ALLOW_UNKNOWN_TAG" -eq 1 ]; then
            echo "Warning: could not find TDLib NetStatsManager.cpp; skipping net-stats parse guard patch."
            return 0
        fi
        fail "Could not find TDLib NetStatsManager.cpp: $netstats_file"
    fi

    if ! grep -q 'log_event_parse(info.stats_by_type\[net_type_i\]\.db_stats, value)\.ensure();' "$netstats_file"; then
        echo "Warning: TDLib NetStatsManager fatal parse call was not found; skipping net-stats parse guard patch."
        return 0
    fi

    cp "$netstats_file" "$netstats_file.telegraphica-netstats-backup"
    perl -0pi -e 's@#include "td/utils/tl_helpers.h"\n@#include "td/utils/tl_helpers.h"\n\n#include <cstring>\n@' "$netstats_file"
    perl -0pi -e 's@      auto value = G\(\)->td_db\(\)->get_binlog_pmc\(\)->get\(key\);\n      if \(value\.empty\(\)\) \{\n        continue;\n      \}\n      log_event_parse\(info\.stats_by_type\[net_type_i\]\.db_stats, value\)\.ensure\(\);@      auto value = G()->td_db()->get_binlog_pmc()->get(key);\n      if (value.empty()) {\n        continue;\n      }\n\n      int32 net_stats_version = -1;\n      if (value.size() < sizeof(net_stats_version)) {\n        LOG(ERROR) << "Drop too short persistent network statistics";\n        G()->td_db()->get_binlog_pmc()->erase(key);\n        continue;\n      }\n      std::memcpy(&net_stats_version, value.data(), sizeof(net_stats_version));\n      if (net_stats_version < 0 || net_stats_version >= static_cast<int32>(Version::Next)) {\n        LOG(ERROR) << "Drop invalid persistent network statistics version " << net_stats_version;\n        G()->td_db()->get_binlog_pmc()->erase(key);\n        continue;\n      }\n\n      auto status = log_event_parse(info.stats_by_type[net_type_i].db_stats, value);\n      if (status.is_error()) {\n        LOG(ERROR) << "Drop unreadable persistent network statistics: " << status;\n        info.stats_by_type[net_type_i].db_stats = NetStatsData();\n        G()->td_db()->get_binlog_pmc()->erase(key);\n        continue;\n      }@' "$netstats_file"

    if grep -q 'log_event_parse(info.stats_by_type\[net_type_i\]\.db_stats, value)\.ensure();' "$netstats_file"; then
        fail "Failed to patch TDLib NetStatsManager fatal parse call in $netstats_file"
    fi
    if ! grep -q 'Drop invalid persistent network statistics version' "$netstats_file"; then
        fail "Failed to add TDLib NetStatsManager version guard in $netstats_file"
    fi

    {
        echo "Patched TDLib NetStatsManager persistent stats parsing for crash resistance."
        echo "File: $netstats_file"
        echo "Replacement: validate log-event version and erase unreadable net_stats keys instead of fatal abort."
    } > "$marker_file"
    echo "Patched TDLib NetStatsManager persistent stats parsing guard."
}

patch_tdlib_for_theme_chat_themes_parse_guard() {
    local source_root="$1"
    local theme_file="$source_root/td/telegram/ThemeManager.cpp"
    local marker_file="$BUILD_DIR/theme-chat-themes-parse-guard-patch.txt"

    if [ "$PATCH_THEME_CHAT_THEMES_PARSE_GUARD" -ne 1 ]; then
        return 0
    fi

    if [ ! -f "$theme_file" ]; then
        if [ "$ALLOW_UNKNOWN_TAG" -eq 1 ]; then
            echo "Warning: could not find TDLib ThemeManager.cpp; skipping chat themes parse guard patch."
            return 0
        fi
        fail "Could not find TDLib ThemeManager.cpp: $theme_file"
    fi

    if grep -q 'get_binlog_pmc()->erase(get_chat_themes_database_key())' "$theme_file"; then
        echo "Warning: TDLib ThemeManager chat themes parse recovery is already patched; skipping."
        return 0
    fi

    if ! grep -q 'LOG(ERROR) << "Failed to parse chat themes from binlog: " << status;' "$theme_file"; then
        echo "Warning: TDLib ThemeManager chat themes parse error branch was not found; skipping chat themes parse guard patch."
        return 0
    fi

    cp "$theme_file" "$theme_file.telegraphica-theme-backup"
    perl -0pi -e 's@      LOG\(ERROR\) << "Failed to parse chat themes from binlog: " << status;\n      chat_themes_ = ChatThemes\(\);@      LOG(ERROR) << "Failed to parse chat themes from binlog: " << status;\n      chat_themes_ = ChatThemes();\n      G()->td_db()->get_binlog_pmc()->erase(get_chat_themes_database_key());@' "$theme_file"

    if ! grep -q 'get_binlog_pmc()->erase(get_chat_themes_database_key())' "$theme_file"; then
        fail "Failed to patch TDLib ThemeManager chat themes parse error branch in $theme_file"
    fi

    {
        echo "Patched TDLib ThemeManager chat themes parse recovery."
        echo "File: $theme_file"
        echo "Replacement: erase unreadable chat_themes cache after parse failure."
    } > "$marker_file"
    echo "Patched TDLib ThemeManager chat themes parse recovery."
}

patch_tdlib_for_messages_notification_settings_parse_guard() {
    local source_root="$1"
    local messages_file="$source_root/td/telegram/MessagesManager.cpp"
    local marker_file="$BUILD_DIR/messages-notification-settings-parse-guard-patch.txt"

    if [ "$PATCH_MESSAGES_NOTIFICATION_SETTINGS_PARSE_GUARD" -ne 1 ]; then
        return 0
    fi

    if [ ! -f "$messages_file" ]; then
        if [ "$ALLOW_UNKNOWN_TAG" -eq 1 ]; then
            echo "Warning: could not find TDLib MessagesManager.cpp; skipping notification settings parse guard patch."
            return 0
        fi
        fail "Could not find TDLib MessagesManager.cpp: $messages_file"
    fi

    if ! grep -q 'log_event_parse(\*current_settings, notification_settings_string)\.ensure();' "$messages_file"; then
        echo "Warning: TDLib MessagesManager notification settings fatal parse call was not found; skipping notification settings parse guard patch."
        return 0
    fi

    cp "$messages_file" "$messages_file.telegraphica-notification-settings-backup"
    perl -0pi -e 's@        log_event_parse\(\*current_settings, notification_settings_string\)\.ensure\(\);\n\n        VLOG\(notifications\) << "Loaded notification settings in " << scope << ": " << \*current_settings;@        auto status = log_event_parse(*current_settings, notification_settings_string);\n        if (status.is_error()) {\n          LOG(ERROR) << "Failed to parse notification settings in " << scope << ": " << status;\n          *current_settings = ScopeNotificationSettings();\n          G()->td_db()->get_binlog_pmc()->erase(get_notification_settings_scope_database_key(scope));\n          continue;\n        }\n\n        VLOG(notifications) << "Loaded notification settings in " << scope << ": " << *current_settings;@' "$messages_file"

    if grep -q 'log_event_parse(\*current_settings, notification_settings_string)\.ensure();' "$messages_file"; then
        fail "Failed to patch TDLib MessagesManager notification settings fatal parse call in $messages_file"
    fi
    if ! grep -q 'Failed to parse notification settings in' "$messages_file"; then
        fail "Failed to add TDLib MessagesManager notification settings recovery in $messages_file"
    fi

    {
        echo "Patched TDLib MessagesManager notification settings parse recovery."
        echo "File: $messages_file"
        echo "Replacement: reset unreadable scope notification settings and erase the damaged binlog key."
    } > "$marker_file"
    echo "Patched TDLib MessagesManager notification settings parse recovery."
}

patch_tdlib_for_stickers_database_parse_guard() {
    local source_root="$1"
    local stickers_cpp="$source_root/td/telegram/StickersManager.cpp"
    local stickers_hpp="$source_root/td/telegram/StickersManager.hpp"
    local marker_file="$BUILD_DIR/stickers-database-parse-guard-patch.txt"

    if [ "$PATCH_STICKERS_DATABASE_PARSE_GUARD" -ne 1 ]; then
        return 0
    fi

    if [ ! -f "$stickers_cpp" ] || [ ! -f "$stickers_hpp" ]; then
        if [ "$ALLOW_UNKNOWN_TAG" -eq 1 ]; then
            echo "Warning: could not find TDLib StickersManager sources; skipping sticker database parse guard patch."
            return 0
        fi
        fail "Could not find TDLib StickersManager sources: $stickers_cpp / $stickers_hpp"
    fi

    if ! grep -q 'Have wrong sticker set id in database' "$stickers_hpp"; then
        if ! grep -q 'CHECK(sticker_set->id.get() == sticker_set_id);' "$stickers_hpp"; then
            echo "Warning: TDLib StickersManager sticker set id check was not found; skipping id parse guard patch."
        else
            cp "$stickers_hpp" "$stickers_hpp.telegraphica-stickers-backup"
            perl -0pi -e 's@  CHECK\(sticker_set->id\.get\(\) == sticker_set_id\);@  if (sticker_set->id.get() != sticker_set_id) {\n    return parser.set_error("Have wrong sticker set id in database");\n  }@' "$stickers_hpp"
        fi
    fi

    if ! grep -q 'Failed to parse sticker set .* from database' "$stickers_cpp"; then
        if ! grep -q 'LOG(FATAL) << "Failed to parse "' "$stickers_cpp"; then
            echo "Warning: TDLib StickersManager fatal database parse branch was not found; skipping sticker parse recovery patch."
        else
            cp "$stickers_cpp" "$stickers_cpp.telegraphica-stickers-backup"
            perl -0pi -e 's@      G\(\)->td_db\(\)->get_sqlite_sync_pmc\(\)->erase\(with_stickers \? get_full_sticker_set_database_key\(sticker_set_id\)\n                                                               : get_sticker_set_database_key\(sticker_set_id\)\);\n      // need to crash, because the current StickerSet state is spoiled by parse_sticker_set\n      LOG\(FATAL\) << "Failed to parse " << sticker_set_id << ": " << status << '"'"' '"'"'\n                 << format::as_hex_dump<4>\(Slice\(value\)\);@      G()->td_db()->get_sqlite_sync_pmc()->erase(with_stickers ? get_full_sticker_set_database_key(sticker_set_id)\n                                                               : get_sticker_set_database_key(sticker_set_id));\n      LOG(ERROR) << "Failed to parse sticker set " << sticker_set_id << " from database: " << status;\n      return do_reload_sticker_set(sticker_set_id, get_input_sticker_set(sticker_set), 0, Auto());@' "$stickers_cpp"
        fi
    fi

    if ! grep -q 'Have wrong sticker set id in database' "$stickers_hpp"; then
        fail "Failed to patch TDLib StickersManager sticker set id parser guard in $stickers_hpp"
    fi
    if ! grep -q 'Failed to parse sticker set .* from database' "$stickers_cpp"; then
        fail "Failed to patch TDLib StickersManager database parse recovery in $stickers_cpp"
    fi

    {
        echo "Patched TDLib StickersManager database parse recovery."
        echo "Files: $stickers_hpp, $stickers_cpp"
        echo "Replacement: treat unreadable cached sticker sets as reloadable database misses instead of fatal aborts."
    } > "$marker_file"
    echo "Patched TDLib StickersManager database parse recovery."
}

patch_tdlib_for_contacts_user_parse_guard() {
    local source_root="$1"
    local contacts_file="$source_root/td/telegram/ContactsManager.cpp"
    local marker_file="$BUILD_DIR/contacts-user-parse-guard-patch.txt"

    if [ "$PATCH_CONTACTS_USER_PARSE_GUARD" -ne 1 ]; then
        return 0
    fi

    if [ ! -f "$contacts_file" ]; then
        if [ "$ALLOW_UNKNOWN_TAG" -eq 1 ]; then
            echo "Warning: could not find TDLib ContactsManager.cpp; skipping user parse guard patch."
            return 0
        fi
        fail "Could not find TDLib ContactsManager.cpp: $contacts_file"
    fi

    if grep -q 'Failed to parse user .* from database' "$contacts_file"; then
        echo "Warning: TDLib ContactsManager user parse recovery is already patched; skipping."
        return 0
    fi

    if ! grep -q 'log_event_parse(\*u, value)\.ensure();' "$contacts_file"; then
        echo "Warning: TDLib ContactsManager user fatal parse call was not found; skipping user parse guard patch."
        return 0
    fi

    cp "$contacts_file" "$contacts_file.telegraphica-user-backup"
    perl -0pi -e 's@      u = add_user\(user_id, "on_load_user_from_database"\);\n\n      log_event_parse\(\*u, value\)\.ensure\(\);\n\n      u->is_saved = true;\n      u->is_status_saved = true;\n      update_user\(u, user_id, true, true\);@      User parsed_user;\n      auto status = log_event_parse(parsed_user, value);\n      if (status.is_error()) {\n        LOG(ERROR) << "Failed to parse user " << user_id << " from database: " << status;\n        G()->td_db()->get_sqlite_sync_pmc()->erase(get_user_database_key(user_id));\n      } else {\n        u = add_user(user_id, "on_load_user_from_database");\n        *u = std::move(parsed_user);\n        u->is_saved = true;\n        u->is_status_saved = true;\n        update_user(u, user_id, true, true);\n      }@' "$contacts_file"

    if grep -q 'log_event_parse(\*u, value)\.ensure();' "$contacts_file"; then
        fail "Failed to patch TDLib ContactsManager user fatal parse call in $contacts_file"
    fi
    if ! grep -q 'Failed to parse user .* from database' "$contacts_file"; then
        fail "Failed to add TDLib ContactsManager user parse recovery in $contacts_file"
    fi

    {
        echo "Patched TDLib ContactsManager user parse recovery."
        echo "File: $contacts_file"
        echo "Replacement: parse cached users into a temporary value and erase unreadable sqlite cache entries."
    } > "$marker_file"
    echo "Patched TDLib ContactsManager user parse recovery."
}

patch_tdlib_for_contacts_list_parse_guard() {
    local source_root="$1"
    local contacts_file="$source_root/td/telegram/ContactsManager.cpp"
    local marker_file="$BUILD_DIR/contacts-list-parse-guard-patch.txt"

    if [ "$PATCH_CONTACTS_LIST_PARSE_GUARD" -ne 1 ]; then
        return 0
    fi

    if [ ! -f "$contacts_file" ]; then
        if [ "$ALLOW_UNKNOWN_TAG" -eq 1 ]; then
            echo "Warning: could not find TDLib ContactsManager.cpp; skipping contacts list parse guard patch."
            return 0
        fi
        fail "Could not find TDLib ContactsManager.cpp: $contacts_file"
    fi

    if grep -q 'Failed to parse contacts from database' "$contacts_file"; then
        echo "Warning: TDLib ContactsManager contacts list parse recovery is already patched; skipping."
        return 0
    fi

    if ! grep -q 'log_event_parse(user_ids, value)\.ensure();' "$contacts_file"; then
        echo "Warning: TDLib ContactsManager contacts list fatal parse call was not found; skipping contacts list parse guard patch."
        return 0
    fi

    cp "$contacts_file" "$contacts_file.telegraphica-contacts-list-backup"
    perl -0pi -e 's@  vector<UserId> user_ids;\n  log_event_parse\(user_ids, value\)\.ensure\(\);\n\n  LOG\(INFO\) << "Successfully loaded " << user_ids\.size\(\) << " contacts from database";@  vector<UserId> user_ids;\n  auto status = log_event_parse(user_ids, value);\n  if (status.is_error()) {\n    LOG(ERROR) << "Failed to parse contacts from database: " << status;\n    G()->td_db()->get_sqlite_pmc()->erase("user_contacts", Auto());\n    G()->td_db()->get_binlog_pmc()->erase("saved_contact_count");\n    saved_contact_count_ = -1;\n    reload_contacts(true);\n    return;\n  }\n\n  LOG(INFO) << "Successfully loaded " << user_ids.size() << " contacts from database";@' "$contacts_file"

    if grep -q 'log_event_parse(user_ids, value)\.ensure();' "$contacts_file"; then
        fail "Failed to patch TDLib ContactsManager contacts list fatal parse call in $contacts_file"
    fi
    if ! grep -q 'Failed to parse contacts from database' "$contacts_file"; then
        fail "Failed to add TDLib ContactsManager contacts list parse recovery in $contacts_file"
    fi

    {
        echo "Patched TDLib ContactsManager contacts list parse recovery."
        echo "File: $contacts_file"
        echo "Replacement: erase unreadable user_contacts sqlite cache and reload contacts from the server."
    } > "$marker_file"
    echo "Patched TDLib ContactsManager contacts list parse recovery."
}

patch_tdlib_for_contacts_chat_parse_guard() {
    local source_root="$1"
    local contacts_file="$source_root/td/telegram/ContactsManager.cpp"
    local marker_file="$BUILD_DIR/contacts-chat-parse-guard-patch.txt"

    if [ "$PATCH_CONTACTS_CHAT_PARSE_GUARD" -ne 1 ]; then
        return 0
    fi

    if [ ! -f "$contacts_file" ]; then
        if [ "$ALLOW_UNKNOWN_TAG" -eq 1 ]; then
            echo "Warning: could not find TDLib ContactsManager.cpp; skipping chat parse guard patch."
            return 0
        fi
        fail "Could not find TDLib ContactsManager.cpp: $contacts_file"
    fi

    if grep -q 'Failed to parse basic group .* from database' "$contacts_file"; then
        echo "Warning: TDLib ContactsManager chat parse recovery is already patched; skipping."
        return 0
    fi

    if ! perl -0ne 'exit(/      c = add_chat\(chat_id\);\n\n      log_event_parse\(\*c, value\)\.ensure\(\);\n\n      c->is_saved = true;\n      update_chat\(c, chat_id, true, true\);/ ? 0 : 1)' "$contacts_file"; then
        echo "Warning: TDLib ContactsManager chat fatal parse call was not found; skipping chat parse guard patch."
        return 0
    fi

    cp "$contacts_file" "$contacts_file.telegraphica-chat-backup"
    perl -0pi -e 's@      c = add_chat\(chat_id\);\n\n      log_event_parse\(\*c, value\)\.ensure\(\);\n\n      c->is_saved = true;\n      update_chat\(c, chat_id, true, true\);@      Chat parsed_chat;\n      auto status = log_event_parse(parsed_chat, value);\n      if (status.is_error()) {\n        LOG(ERROR) << "Failed to parse basic group " << chat_id << " from database: " << status;\n        G()->td_db()->get_sqlite_sync_pmc()->erase(get_chat_database_key(chat_id));\n      } else {\n        c = add_chat(chat_id);\n        *c = std::move(parsed_chat);\n        c->is_saved = true;\n        update_chat(c, chat_id, true, true);\n      }@' "$contacts_file"

    if perl -0ne 'exit(/      c = add_chat\(chat_id\);\n\n      log_event_parse\(\*c, value\)\.ensure\(\);\n\n      c->is_saved = true;\n      update_chat\(c, chat_id, true, true\);/ ? 0 : 1)' "$contacts_file"; then
        fail "Failed to patch TDLib ContactsManager chat fatal parse call in $contacts_file"
    fi
    if ! grep -q 'Failed to parse basic group .* from database' "$contacts_file"; then
        fail "Failed to add TDLib ContactsManager chat parse recovery in $contacts_file"
    fi

    {
        echo "Patched TDLib ContactsManager chat parse recovery."
        echo "File: $contacts_file"
        echo "Replacement: parse cached basic groups into a temporary value and erase unreadable sqlite cache entries."
    } > "$marker_file"
    echo "Patched TDLib ContactsManager chat parse recovery."
}

patch_tdlib_for_contacts_channel_parse_guard() {
    local source_root="$1"
    local contacts_file="$source_root/td/telegram/ContactsManager.cpp"
    local marker_file="$BUILD_DIR/contacts-channel-parse-guard-patch.txt"

    if [ "$PATCH_CONTACTS_CHANNEL_PARSE_GUARD" -ne 1 ]; then
        return 0
    fi

    if [ ! -f "$contacts_file" ]; then
        if [ "$ALLOW_UNKNOWN_TAG" -eq 1 ]; then
            echo "Warning: could not find TDLib ContactsManager.cpp; skipping channel parse guard patch."
            return 0
        fi
        fail "Could not find TDLib ContactsManager.cpp: $contacts_file"
    fi

    if grep -q 'Failed to parse supergroup .* from database' "$contacts_file" &&
        grep -q 'Failed to parse existing supergroup .* from database' "$contacts_file"; then
        echo "Warning: TDLib ContactsManager channel parse recovery is already patched; skipping."
        return 0
    fi

    if ! perl -0ne 'exit(/      c = add_channel\(channel_id, "on_load_channel_from_database"\);\n\n      log_event_parse\(\*c, value\)\.ensure\(\);\n\n      c->is_saved = true;\n      update_channel\(c, channel_id, true, true\);/ ? 0 : 1)' "$contacts_file"; then
        echo "Warning: TDLib ContactsManager channel fatal parse call was not found; skipping channel parse guard patch."
        return 0
    fi

    if ! perl -0ne 'exit(/      Channel temp_c;\n      log_event_parse\(temp_c, value\)\.ensure\(\);\n      if \(c->participant_count == 0 && temp_c\.participant_count != 0\) \{\n        c->participant_count = temp_c\.participant_count;\n        CHECK\(c->is_update_supergroup_sent\);\n        send_closure\(G\(\)->td\(\), &Td::send_update,\n                     make_tl_object<td_api::updateSupergroup>\(get_supergroup_object\(channel_id, c\)\)\);\n      \}\n\n      c->status\.update_restrictions\(\);\n      temp_c\.status\.update_restrictions\(\);\n      if \(temp_c\.status != c->status\) \{\n        on_channel_status_changed\(c, channel_id, temp_c\.status, c->status\);\n        CHECK\(!c->is_being_saved\);\n      \}\n\n      if \(temp_c\.username != c->username\) \{\n        on_channel_username_changed\(c, channel_id, temp_c\.username, c->username\);\n        CHECK\(!c->is_being_saved\);\n      \}/ ? 0 : 1)' "$contacts_file"; then
        echo "Warning: TDLib ContactsManager existing channel fatal parse call was not found; skipping channel parse guard patch."
        return 0
    fi

    cp "$contacts_file" "$contacts_file.telegraphica-channel-backup"
    perl -0pi -e 's@      c = add_channel\(channel_id, "on_load_channel_from_database"\);\n\n      log_event_parse\(\*c, value\)\.ensure\(\);\n\n      c->is_saved = true;\n      update_channel\(c, channel_id, true, true\);@      Channel parsed_channel;\n      auto status = log_event_parse(parsed_channel, value);\n      if (status.is_error()) {\n        LOG(ERROR) << "Failed to parse supergroup " << channel_id << " from database: " << status;\n        G()->td_db()->get_sqlite_sync_pmc()->erase(get_channel_database_key(channel_id));\n      } else {\n        c = add_channel(channel_id, "on_load_channel_from_database");\n        *c = std::move(parsed_channel);\n        c->is_saved = true;\n        update_channel(c, channel_id, true, true);\n      }@' "$contacts_file"

    perl -0pi -e 's@      Channel temp_c;\n      log_event_parse\(temp_c, value\)\.ensure\(\);\n      if \(c->participant_count == 0 && temp_c\.participant_count != 0\) \{\n        c->participant_count = temp_c\.participant_count;\n        CHECK\(c->is_update_supergroup_sent\);\n        send_closure\(G\(\)->td\(\), &Td::send_update,\n                     make_tl_object<td_api::updateSupergroup>\(get_supergroup_object\(channel_id, c\)\)\);\n      \}\n\n      c->status\.update_restrictions\(\);\n      temp_c\.status\.update_restrictions\(\);\n      if \(temp_c\.status != c->status\) \{\n        on_channel_status_changed\(c, channel_id, temp_c\.status, c->status\);\n        CHECK\(!c->is_being_saved\);\n      \}\n\n      if \(temp_c\.username != c->username\) \{\n        on_channel_username_changed\(c, channel_id, temp_c\.username, c->username\);\n        CHECK\(!c->is_being_saved\);\n      \}@      Channel temp_c;\n      auto status = log_event_parse(temp_c, value);\n      if (status.is_error()) {\n        LOG(ERROR) << "Failed to parse existing supergroup " << channel_id << " from database: " << status;\n        G()->td_db()->get_sqlite_sync_pmc()->erase(get_channel_database_key(channel_id));\n      } else {\n        if (c->participant_count == 0 && temp_c.participant_count != 0) {\n          c->participant_count = temp_c.participant_count;\n          CHECK(c->is_update_supergroup_sent);\n          send_closure(G()->td(), &Td::send_update,\n                       make_tl_object<td_api::updateSupergroup>(get_supergroup_object(channel_id, c)));\n        }\n\n        c->status.update_restrictions();\n        temp_c.status.update_restrictions();\n        if (temp_c.status != c->status) {\n          on_channel_status_changed(c, channel_id, temp_c.status, c->status);\n          CHECK(!c->is_being_saved);\n        }\n\n        if (temp_c.username != c->username) {\n          on_channel_username_changed(c, channel_id, temp_c.username, c->username);\n          CHECK(!c->is_being_saved);\n        }\n      }@' "$contacts_file"

    if perl -0ne 'exit(/      c = add_channel\(channel_id, "on_load_channel_from_database"\);\n\n      log_event_parse\(\*c, value\)\.ensure\(\);\n\n      c->is_saved = true;\n      update_channel\(c, channel_id, true, true\);/ ? 0 : 1)' "$contacts_file"; then
        fail "Failed to patch TDLib ContactsManager channel fatal parse call in $contacts_file"
    fi
    if grep -q 'log_event_parse(temp_c, value)\.ensure();' "$contacts_file"; then
        fail "Failed to patch TDLib ContactsManager existing channel fatal parse call in $contacts_file"
    fi
    if ! grep -q 'Failed to parse supergroup .* from database' "$contacts_file"; then
        fail "Failed to add TDLib ContactsManager channel parse recovery in $contacts_file"
    fi
    if ! grep -q 'Failed to parse existing supergroup .* from database' "$contacts_file"; then
        fail "Failed to add TDLib ContactsManager existing channel parse recovery in $contacts_file"
    fi

    {
        echo "Patched TDLib ContactsManager channel parse recovery."
        echo "File: $contacts_file"
        echo "Replacement: parse cached supergroups into temporary values and erase unreadable sqlite cache entries."
    } > "$marker_file"
    echo "Patched TDLib ContactsManager channel parse recovery."
}

patch_tdlib_for_contacts_secret_chat_parse_guard() {
    local source_root="$1"
    local contacts_file="$source_root/td/telegram/ContactsManager.cpp"
    local marker_file="$BUILD_DIR/contacts-secret-chat-parse-guard-patch.txt"

    if [ "$PATCH_CONTACTS_SECRET_CHAT_PARSE_GUARD" -ne 1 ]; then
        return 0
    fi

    if [ ! -f "$contacts_file" ]; then
        if [ "$ALLOW_UNKNOWN_TAG" -eq 1 ]; then
            echo "Warning: could not find TDLib ContactsManager.cpp; skipping secret chat parse guard patch."
            return 0
        fi
        fail "Could not find TDLib ContactsManager.cpp: $contacts_file"
    fi

    if grep -q 'Failed to parse secret chat .* from database' "$contacts_file"; then
        echo "Warning: TDLib ContactsManager secret chat parse recovery is already patched; skipping."
        return 0
    fi

    if ! perl -0ne 'exit(/      c = add_secret_chat\(secret_chat_id\);\n\n      log_event_parse\(\*c, value\)\.ensure\(\);\n\n      c->is_saved = true;\n      update_secret_chat\(c, secret_chat_id, true, true\);/ ? 0 : 1)' "$contacts_file"; then
        echo "Warning: TDLib ContactsManager secret chat fatal parse call was not found; skipping secret chat parse guard patch."
        return 0
    fi

    cp "$contacts_file" "$contacts_file.telegraphica-secret-chat-backup"
    perl -0pi -e 's@      c = add_secret_chat\(secret_chat_id\);\n\n      log_event_parse\(\*c, value\)\.ensure\(\);\n\n      c->is_saved = true;\n      update_secret_chat\(c, secret_chat_id, true, true\);@      SecretChat parsed_secret_chat;\n      auto status = log_event_parse(parsed_secret_chat, value);\n      if (status.is_error()) {\n        LOG(ERROR) << "Failed to parse secret chat " << secret_chat_id << " from database: " << status;\n        G()->td_db()->get_sqlite_sync_pmc()->erase(get_secret_chat_database_key(secret_chat_id));\n      } else {\n        c = add_secret_chat(secret_chat_id);\n        *c = std::move(parsed_secret_chat);\n        c->is_saved = true;\n        update_secret_chat(c, secret_chat_id, true, true);\n      }@' "$contacts_file"

    if perl -0ne 'exit(/      c = add_secret_chat\(secret_chat_id\);\n\n      log_event_parse\(\*c, value\)\.ensure\(\);\n\n      c->is_saved = true;\n      update_secret_chat\(c, secret_chat_id, true, true\);/ ? 0 : 1)' "$contacts_file"; then
        fail "Failed to patch TDLib ContactsManager secret chat fatal parse call in $contacts_file"
    fi
    if ! grep -q 'Failed to parse secret chat .* from database' "$contacts_file"; then
        fail "Failed to add TDLib ContactsManager secret chat parse recovery in $contacts_file"
    fi

    {
        echo "Patched TDLib ContactsManager secret chat parse recovery."
        echo "File: $contacts_file"
        echo "Replacement: parse cached secret chats into a temporary value and erase unreadable sqlite cache entries."
    } > "$marker_file"
    echo "Patched TDLib ContactsManager secret chat parse recovery."
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
    perl -0pi -e 's/auto get_map = \[\&\]\(Document::Type document_type\) \{/auto get_map = [\&](Document::Type document_type) -> decltype(\&animations) {/' "$webpages_file"

    if ! grep -q 'auto get_map = \[&\](Document::Type document_type) -> decltype(&animations) {' "$webpages_file"; then
        fail "Failed to patch TDLib WebPagesManager get_map lambda in $webpages_file"
    fi

    {
        echo "Patched TDLib WebPagesManager get_map lambda to silence false return-stack-address warnings."
        echo "File: $webpages_file"
        echo "Replacement: explicit lambda return type decltype(&animations)."
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
require_command "$CMAKE_MAKE_PROGRAM"
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
patch_tdlib_for_xcode5_scope_exit_heap_guard "$SOURCE_ROOT"
patch_tdlib_for_xcode5_filefd_scope_exit "$SOURCE_ROOT"
patch_tdlib_for_xcode5_status_scope_exit "$SOURCE_ROOT"
patch_tdlib_for_xcode5_ipaddress_scope_exit "$SOURCE_ROOT"
patch_tdlib_for_xcode5_stdstreams_scope_exit "$SOURCE_ROOT"
patch_tdlib_for_xcode5_ordered_events_resize "$SOURCE_ROOT"
patch_tdlib_for_logevent_parser_status "$SOURCE_ROOT"
patch_tdlib_for_netstats_parse_guard "$SOURCE_ROOT"
patch_tdlib_for_theme_chat_themes_parse_guard "$SOURCE_ROOT"
patch_tdlib_for_messages_notification_settings_parse_guard "$SOURCE_ROOT"
patch_tdlib_for_stickers_database_parse_guard "$SOURCE_ROOT"
patch_tdlib_for_contacts_user_parse_guard "$SOURCE_ROOT"
patch_tdlib_for_contacts_list_parse_guard "$SOURCE_ROOT"
patch_tdlib_for_contacts_chat_parse_guard "$SOURCE_ROOT"
patch_tdlib_for_contacts_channel_parse_guard "$SOURCE_ROOT"
patch_tdlib_for_contacts_secret_chat_parse_guard "$SOURCE_ROOT"
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
SDK_PATH="${SDKROOT:-$(xcrun --sdk "$SDK_NAME" --show-sdk-path 2>/dev/null || true)}"

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
    "-DCMAKE_C_FLAGS_RELEASE=$TDLIB_RELEASE_C_FLAGS"
    "-DCMAKE_CXX_FLAGS_RELEASE=$TDLIB_RELEASE_CXX_FLAGS"
    "-DCMAKE_SHARED_LINKER_FLAGS=-mmacosx-version-min=$DEPLOYMENT_TARGET"
    "-DOPENSSL_USE_STATIC_LIBS=TRUE"
    "-DZLIB_USE_STATIC_LIBS=TRUE"
    "-DTD_ENABLE_JNI=OFF"
    "-DTD_ENABLE_DOTNET=OFF"
)

if [ -n "$CMAKE_MAKE_PROGRAM" ]; then
    CMAKE_ARGS+=("-DCMAKE_MAKE_PROGRAM=$CMAKE_MAKE_PROGRAM")
fi
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
    MAKE="$CMAKE_MAKE_PROGRAM" "$CMAKE_BIN" "${CMAKE_ARGS[@]}"
    MAKE="$CMAKE_MAKE_PROGRAM" "$CMAKE_BIN" --build . --target tdjson -- -j "$JOBS" MAKE="$CMAKE_MAKE_PROGRAM"
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
