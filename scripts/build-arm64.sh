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

git clone --no-checkout "$WR64_REPO" "$SRC"
git -C "$SRC" checkout "$WR64_COMMIT"
git -C "$SRC" submodule sync --recursive
git -C "$SRC" submodule update --init --recursive --depth 1

check_submodule() {
  local path="$1"
  local expected="$2"
  local actual
  actual="$(git -C "$SRC/$path" rev-parse HEAD)"
  if [ "$actual" != "$expected" ]; then
    echo "FAIL: $path is $actual, expected $expected" >&2
    exit 1
  fi
  echo "PIN OK: $path $actual"
}

check_submodule lib/N64ModernRuntime "$N64MODERNRUNTIME_COMMIT"
check_submodule lib/RT64 "$RT64_COMMIT"
check_submodule lib/RecompFrontend "$RECOMPFRONTEND_COMMIT"

if [ "$MODE" = "probe" ]; then
  echo "=== ARM64 ROM-free dependency probe ==="

  echo "--- Wave Race CMake configure ---"
  cmake -S "$SRC" -B "$BUILD" -G Ninja \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -DCMAKE_C_COMPILER=clang \
    -DCMAKE_CXX_COMPILER=clang++ \
    -DCMAKE_C_FLAGS="-mcpu=cortex-a53" \
    -DCMAKE_CXX_FLAGS="-mcpu=cortex-a53" \
    -DWR64_WITH_RUNTIME=OFF \
    -DWR64_WITH_RECOMPILED=OFF \
    -DWR64_WITH_FRONTEND=OFF

  echo "--- ARM64 RSP/sse2neon compile probe ---"
  cat > "$WORK/rsp-arm64-probe.cpp" <<'EOF'
#include <librecomp/rsp_vu.hpp>
static_assert(Accuracy::RSP::SIMD);
int main() { return 0; }
EOF

  clang++ -std=c++20 -mcpu=cortex-a53 \
    -I"$SRC/lib/N64ModernRuntime/librecomp/include" \
    -I"$SRC/lib/N64ModernRuntime/thirdparty/sse2neon" \
    -c "$WORK/rsp-arm64-probe.cpp" \
    -o "$WORK/rsp-arm64-probe.o"

  file "$WORK/rsp-arm64-probe.o"

  echo "--- ARM64 Linux DXC patch probe ---"
  git -C "$SRC" apply --check "$ROOT/patches/0001-arm64-linux-dxc.patch"

  DXC="$SRC/lib/RT64/src/contrib/dxc/bin/arm64/dxc-linux"
  if [ -f "$DXC" ]; then
    file "$DXC"
  else
    echo "BLOCKER: pinned RT64 checkout has no $DXC" >&2
    echo "Inspect the pinned RT64 dxc submodule before a full frontend build." >&2
    exit 1
  fi

  echo
  echo "PASS: ROM-free ARM64 dependency probe completed."
  echo "NOTE: the complete game target is intentionally not built here."
  echo "See KNOWN_BLOCKERS.md for the pinned upstream phase-00 header issue."
  exit 0
fi

if [ "$MODE" != "full" ]; then
  echo "Usage: $0 [probe|full]" >&2
  exit 1
fi

ROM="${WR64_ROM:-}"
if [ -z "$ROM" ]; then
  echo "Set WR64_ROM to the supported Wave Race 64 USA Rev A .z64 file." >&2
  exit 2
fi

"$ROOT/scripts/check-rom.sh" "$ROM"

echo
echo "Full ARM64 build is not automated yet."
echo "Next: reproduce upstream generation with the verified ROM, then fix only"
echo "ARM64/runtime blockers demonstrated by the build logs."
exit 2
