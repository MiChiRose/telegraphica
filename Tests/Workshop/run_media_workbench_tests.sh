#!/bin/sh
set -eu

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD_DIR="${TMPDIR:-/tmp}/telegraphica-media-workbench-tests"
mkdir -p "$BUILD_DIR"

clang \
  -fno-objc-arc \
  -fblocks \
  -mmacosx-version-min=10.9 \
  -framework Cocoa \
  -I"$ROOT" \
  "$ROOT/Tests/Workshop/TGMediaWorkbenchTests.m" \
  "$ROOT/WorkshopModules/MediaWorkbench/TGMediaWorkbenchProcessor.m" \
  -o "$BUILD_DIR/TGMediaWorkbenchTests"

"$BUILD_DIR/TGMediaWorkbenchTests"
