#!/bin/sh
set -eu

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD_ROOT="${WORKSHOP_HITL_BUILD_DIR:-$PROJECT_ROOT/build-workshop-hitl}"
APPLICATION_SUPPORT="$HOME/Library/Application Support/Telegraphica"

WORKSHOP_BUILD_DIR="$BUILD_ROOT" \
    "$PROJECT_ROOT/WorkshopModules/scripts/build_modules.sh"

/usr/bin/python "$PROJECT_ROOT/Tests/Workshop/install_hitl_modules.py" \
    "$BUILD_ROOT/Products" \
    "$APPLICATION_SUPPORT"

echo "Workshop HITL modules are installed."
