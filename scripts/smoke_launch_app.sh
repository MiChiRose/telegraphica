#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

APP_PATH="${1:-build-legacy/Release/Telegraphica.app}"
WAIT_SECONDS="${TELEGRAPHICA_SMOKE_WAIT_SECONDS:-10}"

if [ ! -d "$APP_PATH" ]; then
    echo "App bundle was not found: $APP_PATH"
    echo "Build first with ./build_legacy.sh or pass a Telegraphica.app path."
    exit 2
fi

EXECUTABLE="$APP_PATH/Contents/MacOS/Telegraphica"
INFO_PLIST="$APP_PATH/Contents/Info.plist"
if [ ! -x "$EXECUTABLE" ]; then
    echo "App executable is missing or not executable: $EXECUTABLE"
    exit 3
fi
if [ ! -f "$INFO_PLIST" ]; then
    echo "Info.plist is missing: $INFO_PLIST"
    exit 4
fi

SMOKE_HOME="$(mktemp -d "${TMPDIR:-/tmp}/telegraphica-smoke-home.XXXXXX")"
cleanup() {
    if [ -n "${APP_PID:-}" ] && kill -0 "$APP_PID" >/dev/null 2>&1; then
        kill "$APP_PID" >/dev/null 2>&1 || true
        wait "$APP_PID" >/dev/null 2>&1 || true
    fi
    rm -rf "$SMOKE_HOME"
}
trap cleanup EXIT

mkdir -p "$SMOKE_HOME/Library/Application Support" "$SMOKE_HOME/Library/Caches"

echo "Launching $APP_PATH in smoke mode with isolated HOME."
HOME="$SMOKE_HOME" TELEGRAPHICA_SMOKE_LAUNCH=1 "$EXECUTABLE" >/tmp/telegraphica-smoke.stdout 2>/tmp/telegraphica-smoke.stderr &
APP_PID=$!

elapsed=0
while kill -0 "$APP_PID" >/dev/null 2>&1; do
    if [ "$elapsed" -ge "$WAIT_SECONDS" ]; then
        echo "Telegraphica did not finish smoke launch within $WAIT_SECONDS seconds."
        exit 5
    fi
    sleep 1
    elapsed=$((elapsed + 1))
done

if ! wait "$APP_PID"; then
    echo "Telegraphica failed during smoke launch."
    echo "--- stdout ---"
    sed -n '1,120p' /tmp/telegraphica-smoke.stdout 2>/dev/null || true
    echo "--- stderr ---"
    sed -n '1,120p' /tmp/telegraphica-smoke.stderr 2>/dev/null || true
    exit 5
fi

APP_PID=""
echo "Smoke launch passed: app initialized and exited cleanly."
