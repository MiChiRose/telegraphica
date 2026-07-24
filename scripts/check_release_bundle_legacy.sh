#!/bin/bash
set -euo pipefail

APP_PATH="${1:-}"
DEPLOYMENT_TARGET="${2:-${MACOSX_DEPLOYMENT_TARGET:-10.8}}"
ARCH="${TELEGRAPHICA_ARCH:-x86_64}"

if [ -z "$APP_PATH" ] || [ ! -d "$APP_PATH/Contents" ]; then
    echo "Usage: $0 /path/to/Telegraphica.app [minimum-system-version]"
    exit 1
fi

for command_name in file lipo nm otool shasum; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        echo "$command_name was not found."
        exit 1
    fi
done

version_gt() {
    awk -v left="$1" -v right="$2" '
        BEGIN {
            split(left, a, ".");
            split(right, b, ".");
            for (i = 1; i <= 3; i++) {
                av = (a[i] == "" ? 0 : a[i]) + 0;
                bv = (b[i] == "" ? 0 : b[i]) + 0;
                if (av > bv) exit 0;
                if (av < bv) exit 1;
            }
            exit 1;
        }
    '
}

resolve_bundle_dependency() {
    local binary_path="$1"
    local dependency="$2"
    local relative_path=""

    case "$dependency" in
        @loader_path/*)
            relative_path="${dependency#@loader_path/}"
            [ -f "$(dirname "$binary_path")/$relative_path" ]
            ;;
        @executable_path/*)
            relative_path="${dependency#@executable_path/}"
            [ -f "$APP_PATH/Contents/MacOS/$relative_path" ]
            ;;
        @rpath/*)
            relative_path="${dependency#@rpath/}"
            [ -f "$APP_PATH/Contents/Frameworks/$relative_path" ] ||
                [ -f "$APP_PATH/Contents/MacOS/$relative_path" ] ||
                [ -f "$(dirname "$binary_path")/$relative_path" ]
            ;;
        *)
            return 0
            ;;
    esac
}

INFO_PLIST="$APP_PATH/Contents/Info.plist"
PLIST_MINIMUM="$(/usr/libexec/PlistBuddy -c "Print :LSMinimumSystemVersion" "$INFO_PLIST" 2>/dev/null || true)"
if [ "$PLIST_MINIMUM" != "$DEPLOYMENT_TARGET" ]; then
    echo "Bundle minimum system version is $PLIST_MINIMUM, expected $DEPLOYMENT_TARGET."
    exit 1
fi

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/telegraphica-bundle-audit.XXXXXX")"
cleanup() {
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT

MACHO_LIST="$WORK_DIR/macho-files.txt"
MANIFEST_PATH="${TELEGRAPHICA_BUNDLE_MANIFEST_PATH:-$APP_PATH/Contents/Resources/TelegraphicaLegacyBinaryManifest.tsv}"
: > "$MACHO_LIST"
find "$APP_PATH/Contents" -type f -print | while IFS= read -r candidate; do
    if file "$candidate" 2>/dev/null | grep -q "Mach-O"; then
        echo "$candidate"
    fi
done > "$MACHO_LIST"

if [ ! -s "$MACHO_LIST" ]; then
    echo "No Mach-O files were found in $APP_PATH."
    exit 1
fi

printf "sha256\tarchitecture\tminimum_os\tinstall_name\tbundle_path\n" > "$MANIFEST_PATH"

while IFS= read -r binary_path; do
    relative_path="${binary_path#"$APP_PATH"/}"
    architectures="$(lipo -archs "$binary_path" 2>/dev/null || true)"
    if ! echo "$architectures" | tr ' ' '\n' | grep -qx "$ARCH"; then
        echo "$relative_path does not contain $ARCH."
        exit 1
    fi

    load_commands="$(otool -arch "$ARCH" -l "$binary_path" 2>/dev/null || true)"
    if echo "$load_commands" | grep -q "LC_BUILD_VERSION"; then
        echo "$relative_path uses LC_BUILD_VERSION and is not a legacy release binary."
        exit 1
    fi
    minimum_os="$(echo "$load_commands" | awk '/LC_VERSION_MIN_MACOSX/{found=1} found && /version /{print $2; exit}')"
    if [ -z "$minimum_os" ]; then
        echo "$relative_path has no LC_VERSION_MIN_MACOSX command."
        exit 1
    fi
    if version_gt "$minimum_os" "$DEPLOYMENT_TARGET"; then
        echo "$relative_path requires OS X $minimum_os, expected <= $DEPLOYMENT_TARGET."
        exit 1
    fi

    if echo "$load_commands" | grep -E -q "__LLVM|__llvm|__llvm_prf"; then
        echo "$relative_path contains profiling/LLVM sections."
        exit 1
    fi

    install_name="$(otool -arch "$ARCH" -D "$binary_path" 2>/dev/null | awk 'NR == 2 {print $1}')"
    linked_libraries="$(otool -arch "$ARCH" -L "$binary_path" 2>/dev/null | awk 'NR > 1 {print $1}')"
    while IFS= read -r dependency; do
        [ -z "$dependency" ] && continue
        case "$dependency" in
            /usr/lib/*|/System/Library/*)
                ;;
            /usr/local/*|/opt/*|/Applications/*|*/DerivedData/*|*/build-legacy/*)
                echo "$relative_path contains a non-portable dependency: $dependency"
                exit 1
                ;;
            @loader_path/*|@executable_path/*|@rpath/*)
                if ! resolve_bundle_dependency "$binary_path" "$dependency"; then
                    echo "$relative_path has an unresolved bundle dependency: $dependency"
                    exit 1
                fi
                ;;
            "$binary_path")
                ;;
            *)
                echo "$relative_path contains an unsupported dependency path: $dependency"
                exit 1
                ;;
        esac
    done <<EOF
$linked_libraries
EOF

    checksum="$(shasum -a 256 "$binary_path" | awk '{print $1}')"
    printf "%s\t%s\t%s\t%s\t%s\n" \
        "$checksum" "$architectures" "$minimum_os" "$install_name" "$relative_path" >> "$MANIFEST_PATH"
done < "$MACHO_LIST"

echo "Legacy bundle audit passed for $(wc -l < "$MACHO_LIST" | tr -d ' ') Mach-O file(s)."
echo "Binary manifest: $MANIFEST_PATH"
