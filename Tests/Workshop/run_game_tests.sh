#!/bin/sh
set -eu

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD_DIR="${TMPDIR:-/tmp}/telegraphica-workshop-game-tests"
mkdir -p "$BUILD_DIR"

clang \
  -fno-objc-arc \
  -fblocks \
  -mmacosx-version-min=10.9 \
  -framework Cocoa \
  -I"$ROOT" \
  "$ROOT/Tests/Workshop/TGWorkshopGameTests.m" \
  "$ROOT/WorkshopModules/Common/TGGameSaveStore.m" \
  "$ROOT/WorkshopModules/TicTacToe/TGTicTacToeEngine.m" \
  "$ROOT/WorkshopModules/Minesweeper/TGMinesweeperEngine.m" \
  "$ROOT/WorkshopModules/Checkers/TGCheckersEngine.m" \
  "$ROOT/WorkshopModules/Solitaire/TGSolitaireEngine.m" \
  "$ROOT/WorkshopModules/PacMan/TGPacManEngine.m" \
  "$ROOT/WorkshopModules/Fifteen/TGFifteenEngine.m" \
  "$ROOT/WorkshopModules/TankPatrol/TGTankPatrolEngine.m" \
  -o "$BUILD_DIR/TGWorkshopGameTests"

"$BUILD_DIR/TGWorkshopGameTests"
