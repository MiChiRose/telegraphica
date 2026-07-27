#!/bin/sh
set -eu

# Telegraphica does not ship games, firmware, or artwork. This script only builds
# two open-source libretro cores from source trees supplied by the developer.
# Verified upstream revisions:
#   QuickNES:         26bb785c9deddb66a17717b21bb4e328f03ade32
#   Genesis Plus GX: f687c49dc4b825101f26a483b222620686616b78

if [ "$#" -ne 3 ]; then
    echo "usage: build_retro_cores.sh QUICKNES_SOURCE GENESIS_PLUS_GX_SOURCE OUTPUT_DIR" >&2
    exit 2
fi

quicknes_source="$(cd "$1" && pwd)"
genesis_source="$(cd "$2" && pwd)"
output_dir="$3"

if [ ! -f "$quicknes_source/Makefile" ] || [ ! -f "$quicknes_source/libretro/libretro.cpp" ]; then
    echo "Invalid QuickNES source tree: $quicknes_source" >&2
    exit 3
fi
if [ ! -f "$genesis_source/Makefile.libretro" ] || [ ! -d "$genesis_source/libretro" ]; then
    echo "Invalid Genesis Plus GX source tree: $genesis_source" >&2
    exit 4
fi

mkdir -p "$output_dir"
compiler_flags="-arch x86_64 -mmacosx-version-min=10.9"

(cd "$quicknes_source" && \
    make -f Makefile clean && \
    make -f Makefile platform=osx arch=intel \
        CC=clang CXX=clang++ \
        CFLAGS="$compiler_flags" CXXFLAGS="$compiler_flags" \
        LDFLAGS="$compiler_flags")

(cd "$genesis_source" && \
    make -f Makefile.libretro clean && \
    make -f Makefile.libretro platform=osx arch=intel NOUNIVERSAL=1 HAVE_CHD=0 HAVE_CDROM=0 \
        CC=clang CXX=clang++ LD=clang \
        CFLAGS="$compiler_flags" CXXFLAGS="$compiler_flags" \
        LDFLAGS="$compiler_flags")

cp "$quicknes_source/quicknes_libretro.dylib" "$output_dir/quicknes_libretro.dylib"
cp "$genesis_source/genesis_plus_gx_libretro.dylib" "$output_dir/genesis_plus_gx_libretro.dylib"
chmod 755 "$output_dir/quicknes_libretro.dylib" "$output_dir/genesis_plus_gx_libretro.dylib"

file "$output_dir/quicknes_libretro.dylib"
file "$output_dir/genesis_plus_gx_libretro.dylib"
echo "Retro cores are ready in $output_dir"
