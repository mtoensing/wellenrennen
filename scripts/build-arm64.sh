#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/versions.sh"

MODE="${1:-probe}"
WORK="$ROOT/.work"
SRC="$WORK/wave-race-64-recomp"
BUILD="$WORK/build-arm64"
DIST="$ROOT/dist"

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required tool: $1" >&2
    exit 1
  }
}

for tool in git cmake ninja clang clang++ python3 file; do
  need "$tool"
done

rm -rf "$SRC" "$BUILD" "$DIST"
mkdir -p "$WORK" "$DIST"

git clone "$WR64_REPO" "$SRC"
git -C "$SRC" checkout "$WR64_COMMIT"

if [ "$MODE" = "probe" ]; then
  echo "=== ARM64 ROM-free probe build ==="
  cmake -S "$SRC" -B "$BUILD" -G Ninja \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -DCMAKE_C_COMPILER=clang \
    -DCMAKE_CXX_COMPILER=clang++ \
    -DCMAKE_C_FLAGS="-mcpu=cortex-a53" \
    -DCMAKE_CXX_FLAGS="-mcpu=cortex-a53" \
    -DWR64_WITH_RUNTIME=OFF \
    -DWR64_WITH_RECOMPILED=OFF \
    -DWR64_WITH_FRONTEND=OFF
  cmake --build "$BUILD" -j"$(nproc)" --target WaveRace64Recomp
  file "$BUILD/WaveRace64Recomp"
  echo "PASS: ROM-free ARM64 probe build completed."
  exit 0
fi

if [ "$MODE" != "full" ]; then
  echo "Usage: $0 [probe|full]" >&2
  exit 1
fi

echo "Full ARM64 build is intentionally gated."
echo "It requires the user's verified USA Rev A ROM to generate RecompiledFuncs/."
echo "Follow AGENTS.md and fix only observed ARM64/runtime blockers."
echo
echo "Expected ROM SHA-1: $WR64_ROM_SHA1"
exit 2
