#!/usr/bin/env bash
# Run scripts/build-arm64.sh inside the aarch64 Ubuntu 22.04 image from
# docker/Dockerfile (needs an aarch64 Docker host, e.g. colima on Apple Silicon).
#
# The work tree (pinned source, reference decomp, ROM-derived RecompiledFuncs/,
# build output) lives in the Docker volume "wr64-work", never in this repo.
# Only the finished binary is copied back to dist/.
#
#   WR64_ROM=/path/to/rom.z64 bash scripts/build-arm64-docker.sh full
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="${1:-probe}"
IMAGE="wellenrennen-build:22.04"

docker build -q -t "$IMAGE" "$ROOT/docker" >/dev/null

ARGS=(--rm -v "$ROOT:/repo" -v wr64-work:/work -e WR64_WORK=/work -e WR64_DIST=/work/dist)
if [ "$MODE" = "full" ]; then
  : "${WR64_ROM:?Set WR64_ROM to the Wave Race 64 USA Rev A .z64}"
  ARGS+=(-v "$(cd "$(dirname "$WR64_ROM")" && pwd)/$(basename "$WR64_ROM"):/rom/baserom.z64:ro"
         -e WR64_ROM=/rom/baserom.z64)
fi

docker run "${ARGS[@]}" "$IMAGE" bash /repo/scripts/build-arm64.sh "$MODE"

if [ "$MODE" = "full" ]; then
  mkdir -p "$ROOT/dist"
  docker run --rm -v wr64-work:/work -v "$ROOT/dist:/out" "$IMAGE" \
    cp /work/build-arm64/WaveRace64Recomp /out/WaveRace64Recomp.aarch64
  ls -la "$ROOT/dist/WaveRace64Recomp.aarch64"
fi
