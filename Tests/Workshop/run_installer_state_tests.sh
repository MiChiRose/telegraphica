#!/bin/sh
set -eu

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD_DIR="${TMPDIR:-/tmp}/telegraphica-workshop-installer-tests"
TEST_ROOT="$BUILD_DIR/root"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR" "$TEST_ROOT"

clang \
  -fno-objc-arc \
  -fblocks \
  -DTELEGRAPHICA_WORKSHOP_TESTING=1 \
  -mmacosx-version-min=10.9 \
  -framework Cocoa \
  -I"$ROOT" \
  "$ROOT/Tests/Workshop/TGWorkshopInstallerStateTests.m" \
  "$ROOT/Sources/Workshop/Installation/TGWorkshopInstaller.m" \
  "$ROOT/Sources/Workshop/Installation/TGWorkshopRegistryStore.m" \
  "$ROOT/Sources/Workshop/Host/TGWorkshopPaths.m" \
  -o "$BUILD_DIR/TGWorkshopInstallerStateTests"

TELEGRAPHICA_WORKSHOP_TEST_ROOT="$TEST_ROOT" "$BUILD_DIR/TGWorkshopInstallerStateTests"
