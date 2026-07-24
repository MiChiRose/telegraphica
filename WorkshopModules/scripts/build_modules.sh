#!/bin/sh
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MODULES_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$MODULES_ROOT/.." && pwd)"
OUTPUT_ROOT="${WORKSHOP_BUILD_DIR:-$PROJECT_ROOT/build-workshop}"
OBJECT_ROOT="$OUTPUT_ROOT/Objects"
PRODUCT_ROOT="$OUTPUT_ROOT/Products"
SDKROOT="${SDKROOT:-$(xcrun --sdk macosx --show-sdk-path)}"
CLANG="${CLANG:-$(xcrun --find clang)}"

rm -rf "$OBJECT_ROOT" "$PRODUCT_ROOT"
mkdir -p "$OBJECT_ROOT" "$PRODUCT_ROOT"

build_module() {
    module_name="$1"
    principal_source="$2"
    module_dir="$MODULES_ROOT/$module_name"
    object_dir="$OBJECT_ROOT/$module_name"
    bundle_dir="$PRODUCT_ROOT/$module_name.bundle"
    executable_dir="$bundle_dir/Contents/MacOS"
    resources_dir="$bundle_dir/Contents/Resources"
    executable="$executable_dir/$module_name"

    mkdir -p "$object_dir" "$executable_dir" "$resources_dir"
    objects=""
    for source in "$MODULES_ROOT/Common/TGGameSaveStore.m" "$module_dir"/*.m; do
        base="$(basename "$source" .m)"
        object="$object_dir/$base.o"
        "$CLANG" -c "$source" -o "$object" \
            -arch x86_64 \
            -fblocks \
            -fno-objc-arc \
            -mmacosx-version-min=10.9 \
            -Os \
            -isysroot "$SDKROOT" \
            -I"$MODULES_ROOT/Common" \
            -I"$module_dir" \
            -I"$PROJECT_ROOT/Sources/Workshop/API"
        objects="$objects $object"
    done

    # Workshop API classes live in the host app, so module references are resolved
    # when NSBundle loads the bundle into Telegraphica.
    "$CLANG" -bundle -o "$executable" $objects \
        -arch x86_64 \
        -mmacosx-version-min=10.9 \
        -isysroot "$SDKROOT" \
        -framework Cocoa \
        -framework QuartzCore \
        -undefined dynamic_lookup
    chmod 755 "$executable"
    cp "$module_dir/Info.plist" "$bundle_dir/Contents/Info.plist"
    cp "$module_dir/WorkshopModule.plist" "$resources_dir/WorkshopModule.plist"
    if [ -d "$module_dir/Resources" ]; then
        cp -R "$module_dir/Resources/." "$resources_dir/"
    fi

    if [ ! -x "$executable" ]; then
        echo "Missing bundle executable for $module_name" >&2
        exit 1
    fi
    if [ "$principal_source" = "" ]; then
        echo "Missing principal class for $module_name" >&2
        exit 1
    fi
    echo "Built $bundle_dir"
}

build_module "TicTacToe" "TGTicTacToeModule"
build_module "Minesweeper" "TGMinesweeperModule"
build_module "Checkers" "TGCheckersModule"
build_module "Solitaire" "TGSolitaireModule"
build_module "PacMan" "TGPacManModule"
build_module "Fifteen" "TGFifteenModule"
build_module "DiagnosticCenter" "TGDiagnosticCenterModule"
build_module "MediaWorkbench" "TGMediaWorkbenchModule"

echo "Workshop modules are ready in $PRODUCT_ROOT"
