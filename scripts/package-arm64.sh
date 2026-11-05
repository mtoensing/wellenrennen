#!/usr/bin/env bash
# Package the Docker-built ARM64 binary as dist/wellenrennen.zip.
#
# Run after: WR64_ROM=... bash scripts/build-arm64-docker.sh full
#
# The game renders through the GLideN64 mupen64plus plugin on the CFW's own
# SDL2 + OpenGL ES, so the only bundled binary besides the game is that plugin
# (GPL-2.0, built from the pinned GLideN64 revision). No ROM or ROM-derived
# data is packaged: the game code is compiled into the binary from the user's
# ROM, which the user supplies again at runtime.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE="wellenrennen-build:22.04"
STAGE="$ROOT/dist/stage"
PORT="$STAGE/wellenrennen"

rm -rf "$STAGE" "$ROOT/dist/wellenrennen.zip"
mkdir -p "$PORT/gliden64"

cp -R "$ROOT/portmaster/wellenrennen/." "$PORT/"
mv "$PORT/Wellenrennen.sh" "$STAGE/Wellenrennen.sh"

# Binary, the assets CMake staged beside it, and the renderer plugin.
docker run --rm -v wr64-work:/work -v "$ROOT:/repo:ro" -v "$PORT:/out" "$IMAGE" bash -c '
  set -e
  cp /work/build-arm64/WaveRace64Recomp /out/WaveRace64Recomp.aarch64
  # The native port deliberately excludes the optional unlicensed PC frontend.
  mkdir -p /out/assets
  cp -R /work/wave-race-64-recomp/assets/water /out/assets/water
  cp /work/build-gliden64/plugin/Release/mupen64plus-video-GLideN64.so /out/gliden64/
  cp /work/build-arm64/libwr64_m64pcore.so /out/gliden64/
  strip --strip-debug /out/WaveRace64Recomp.aarch64 /out/gliden64/*.so
  python3 /repo/scripts/collect-portmaster-licenses.py /out/licenses
  printf "{\"frontend\": false, \"profile\": \"native-gles\"}\n" > /out/build-info.json
'

( cd "$STAGE" && zip -qr "$ROOT/dist/wellenrennen.zip" Wellenrennen.sh wellenrennen )
ls -la "$ROOT/dist/wellenrennen.zip"
