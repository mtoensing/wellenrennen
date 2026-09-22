#!/usr/bin/env bash
# Package the Docker-built ARM64 binary as dist/wellenrennen.zip.
#
# Run after: WR64_ROM=... bash scripts/build-arm64-docker.sh full
#
# Bundled libraries are only what the PortMaster runtimes (Westonpack,
# Mesapack) and the CFW do not provide, each pinned by SHA-256:
#   - libvulkan.so.1 (Khronos loader, Apache-2.0; Mesapack ships the Lavapipe
#     ICD but no loader)
#   - libxcb-{randr,dri3,present,sync} (MIT; Lavapipe links them, neither
#     runtime ships them)
#   - libSDL2-2.0.so.0 with X11 (zlib; the CFW's SDL2 has only its Mali video
#     driver). Same binary the Westonpack wiki points ports at.
# No ROM or ROM-derived data is packaged: the game code is compiled into the
# binary from the user's ROM, which the user supplies again at runtime.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE="wellenrennen-build:22.04"
STAGE="$ROOT/dist/stage"
PORT="$STAGE/wellenrennen"
LIBS="$PORT/libs.aarch64"

SDL_COMMIT="5e5af60c490d85ff163313550f20cd26d0a20327"
SDL_URL="https://github.com/PortsMaster/PortMaster-New/raw/$SDL_COMMIT/ports/superhexagon/superhexagon/libs.aarch64/libSDL2-2.0.so.0"

rm -rf "$STAGE" "$ROOT/dist/wellenrennen.zip"
mkdir -p "$LIBS"

cp -R "$ROOT/portmaster/wellenrennen/." "$PORT/"
mv "$PORT/Wellenrennen.sh" "$STAGE/Wellenrennen.sh"

# Binary and the assets CMake staged beside it.
docker run --rm -v wr64-work:/work -v "$PORT:/out" "$IMAGE" bash -c '
  set -e
  cp /work/build-arm64/WaveRace64Recomp /out/WaveRace64Recomp.aarch64
  cp -R /work/build-arm64/assets /out/assets
  # Baseline bring-up (AGENTS.md): original music and textures. The
  # replacement soundtrack is decoded fully into RAM at startup (~300 MB),
  # which leaves too little of the 1 GB for the 512 MiB librecomp RDRAM commit.
  rm -rf /out/assets/music /out/assets/textures
  apt-get update -qq >/dev/null
  apt-get install -y -qq libvulkan1 libxcb-randr0 libxcb-dri3-0 libxcb-present0 libxcb-sync1 >/dev/null 2>&1
  for l in libvulkan.so.1 libxcb-randr.so.0 libxcb-dri3.so.0 libxcb-present.so.0 libxcb-sync.so.1; do
    cp -L /usr/lib/aarch64-linux-gnu/$l /out/libs.aarch64/
  done
'
curl -fsSL -o "$LIBS/libSDL2-2.0.so.0" "$SDL_URL"

( cd "$LIBS" && shasum -a 256 -c - ) <<'EOF'
4d5f7e264c73cd20ed149e258536a087b7185747450b5a811ab3e8c702998e89  libvulkan.so.1
1e69da8f09cc92820a1c00bf5012f5a41cec860b8ba565163abb71bad6bb1d6d  libxcb-randr.so.0
f5722bd5f9b7d6d7946735705bd9d6d42431e83c6e1fb57c2f26f2a684a808be  libxcb-dri3.so.0
b5c183f85094a5befc6c87ddb99ff593b9301da7c9c66e9f132353b689f82a7b  libxcb-present.so.0
54d0254da49a873faa3ebb64cfd40253ac1d13240b36a3db91016ba8c488f201  libxcb-sync.so.1
6aeb6036d81c2618a1d466b16e5229de01f209260cffc2bd41799bf9ffb2657d  libSDL2-2.0.so.0
EOF

( cd "$STAGE" && zip -qr "$ROOT/dist/wellenrennen.zip" Wellenrennen.sh wellenrennen )
ls -la "$ROOT/dist/wellenrennen.zip"
