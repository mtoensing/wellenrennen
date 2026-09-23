#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/versions.sh"

MODE="${1:-probe}"
WORK="${WR64_WORK:-$ROOT/.work}"
SRC="$WORK/wave-race-64-recomp"
BUILD="$WORK/build-arm64"
DIST="${WR64_DIST:-$ROOT/dist}"

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required tool: $1" >&2
    exit 1
  }
}

for tool in git cmake ninja clang clang++ python3 file; do
  need "$tool"
done

# The probe always starts clean. The full build reuses a checkout that is
# already at the pinned revision: the ROM-derived generation and the
# RecompiledFuncs/ compile take long, and the upstream patch scripts are
# idempotent.
if [ "$MODE" = "probe" ] || [ "$(git -C "$SRC" rev-parse HEAD 2>/dev/null)" != "$WR64_COMMIT" ]; then
  rm -rf "$SRC" "$BUILD"
  mkdir -p "$WORK"
  git clone --no-checkout "$WR64_REPO" "$SRC"
  git -C "$SRC" checkout "$WR64_COMMIT"
fi
rm -rf "$DIST"
mkdir -p "$DIST"
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

bash "$ROOT/scripts/check-rom.sh" "$ROM"

need mips-linux-gnu-as

# --- upstream source patches (same set as upstream's build_macos.sh, minus
# the macOS one) plus our ARM64 DXC selection ---
cd "$SRC"
# patches/NNNN-*.patch apply to the Wave Race tree, patches/<submodule>-*.patch
# to that submodule. Tracked sources are reset to the pinned revisions first so
# the series always applies from the same base (ROM-derived output is untracked
# and survives the reset).
reset_tree() {
  git -C "$1" checkout -q -- .
  git -C "$1" clean -q -f -- src include 2>/dev/null || true
}
reset_tree "$SRC"
reset_tree "$SRC/lib/RecompFrontend"
reset_tree "$SRC/lib/N64ModernRuntime"
for p in "$ROOT"/patches/[0-9]*.patch; do git -C "$SRC" apply "$p"; echo "patched: $(basename "$p")"; done
for p in "$ROOT"/patches/recompfrontend-*.patch; do git -C "$SRC/lib/RecompFrontend" apply "$p"; echo "patched: $(basename "$p")"; done
for p in "$ROOT"/patches/n64modernruntime-*.patch; do git -C "$SRC/lib/N64ModernRuntime" apply "$p"; echo "patched: $(basename "$p")"; done
for patch in patch_rt64.py patch_n64recomp.py patch_rsprecomp.py \
             patch_librecomp.py patch_water.py patch_runtime_shutdown.py \
             patch_texture_packs.py; do
  python3 "tools/$patch"
done

# --- recompiler tools ---
cmake -S lib/N64ModernRuntime/N64Recomp -B build-tools -G Ninja \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++
cmake --build build-tools --target N64RecompCLI RSPRecomp

# --- ROM-derived sources (never leave this work tree) ---
if [ ! -f RecompiledFuncs/aspMain_rsp.cpp ]; then
  if [ ! -d reference/wr64-decomp/.git ]; then
    git clone "$WR64_DECOMP_REPO" reference/wr64-decomp
  fi
  git -C reference/wr64-decomp checkout -q "$WR64_DECOMP_COMMIT"
  git -C reference/wr64-decomp submodule update --init --recursive

  VENV="$WORK/venv"
  if [ ! -x "$VENV/bin/python" ]; then
    python3 -m venv "$VENV"
    "$VENV/bin/pip" install -q PyYAML==6.0.3 pylibyaml==0.1.0 tqdm==4.67.1 \
      intervaltree==3.1.0 colorama==0.4.6 spimdisasm==1.42.4 rabbitizer==1.16.2 \
      pygfxd==1.0.5 n64img==0.3.3 crunch64==0.6.2
  fi
  # Upstream's pad_* helpers document ~/wr64venv; generate_game.py runs them
  # with sys.executable, so running it from the venv is enough.
  "$VENV/bin/python" tools/generate_game.py "$ROM"
fi

# --- GLideN64 (OpenGL ES renderer plugin) ---
# RT64 needs Vulkan; the Mali GLES-only drivers of these CFWs cannot run it.
GLIDEN64_SRC="$WORK/GLideN64"
GLIDEN64_BUILD="$WORK/build-gliden64"
if [ "$(git -C "$GLIDEN64_SRC" rev-parse HEAD 2>/dev/null)" != "$GLIDEN64_COMMIT" ]; then
  rm -rf "$GLIDEN64_SRC" "$GLIDEN64_BUILD"
  git clone "$GLIDEN64_REPO" "$GLIDEN64_SRC"
  git -C "$GLIDEN64_SRC" checkout -q "$GLIDEN64_COMMIT"
fi
git -C "$GLIDEN64_SRC" checkout -q -- .
for p in "$ROOT"/patches/gliden64-*.patch; do git -C "$GLIDEN64_SRC" apply "$p"; echo "patched: $(basename "$p")"; done
# Ubuntu 22.04's zstd has no CMake package; GLideN64 only needs the static lib.
mkdir -p "$WORK/cmake-shims"
cat > "$WORK/cmake-shims/ZSTDConfig.cmake" <<'ZSTD'
add_library(zstd::libzstd_static STATIC IMPORTED)
set_target_properties(zstd::libzstd_static PROPERTIES
  IMPORTED_LOCATION /usr/lib/aarch64-linux-gnu/libzstd.a
  INTERFACE_INCLUDE_DIRECTORIES /usr/include)
ZSTD
cmake -S "$GLIDEN64_SRC/src" -B "$GLIDEN64_BUILD" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ \
  -DCMAKE_C_FLAGS="-mcpu=cortex-a53" -DCMAKE_CXX_FLAGS="-mcpu=cortex-a53" \
  -DMUPENPLUSAPI=ON -DEGL=ON -DNEON_OPT=ON -DCRC_ARMV8=ON -DNO_OSD=ON \
  -DUSE_IPO=OFF -DUSE_SYSTEM_LIBS=ON -DZSTD_DIR="$WORK/cmake-shims"
cmake --build "$GLIDEN64_BUILD"
cd "$SRC"

# --- the game ---
# NFD_PORTAL: RT64's file dialog uses xdg-desktop-portal over D-Bus instead of
# GTK 3, which CFWs do not ship. The port passes the ROM on the command line.
# RT64 only defines PLUME_SDL_VULKAN_ENABLED inside its own directory scope.
# RecompFrontend is a sibling and would otherwise see plume's X11
# RenderWindow while ultramodern hands it an SDL_Window*.
cmake -S . -B "$BUILD" -G Ninja \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ \
  -DRT64_SDL_WINDOW_VULKAN=ON \
  -DNFD_PORTAL=ON \
  -DWR64_GLIDEN64_INCLUDE_DIR="$GLIDEN64_SRC/src/inc" \
  -DCMAKE_C_FLAGS="-DPLUME_SDL_VULKAN_ENABLED" \
  -DCMAKE_CXX_FLAGS="-DPLUME_SDL_VULKAN_ENABLED" \
  -DSDL2_INCLUDE_DIRS="$(sdl2-config --cflags | sed -n 's/.*-I\([^ ]*\).*/\1/p')" \
  -DWR64_WITH_RUNTIME=ON -DWR64_WITH_RECOMPILED=ON -DWR64_WITH_FRONTEND=ON
cmake --build "$BUILD" --target WaveRace64Recomp

file "$BUILD/WaveRace64Recomp"
echo "PASS: built $BUILD/WaveRace64Recomp"
