# Exact references

## Wave Race 64: Recompiled

- https://github.com/elliotttate/wave-race-64-recomp
- pinned commit: `9041cc8024f6d2015859f88f5a0307b36cd4e50a`
- build guide: `docs/BUILDING.md`
- root build logic: `CMakeLists.txt`
- required ROM: Wave Race 64 (USA) (Rev A)
- required ROM SHA-1: `508dfc2d4caa42b6f6de5263d0aed5e44ac7966a`

Pinned submodules at that upstream revision:

- N64ModernRuntime: `cdf5abbd5026fef5c364c676e4667c45e42b6863`
- RT64: `5473732a822a4423b5696e7cb18fecc425a59875`
- RecompFrontend: `b1a1477c6556aeb7ed45defbfb5924f721efebc1`

## Reference decompilation

- https://github.com/LLONSIT/Wave-Race-64
- revision used by upstream build instructions:
  `a51b38a2aaef68da10ea1e47247e70be3b1d4c70`

## PortMaster

- https://github.com/PortsMaster/PortMaster-New
- mandatory AI guidance: `AGENTS.md`
- packaging docs: https://portmaster.games/packaging.html

## ARM64 facts to verify during bring-up

- N64ModernRuntime has an aarch64 RSP vector path through `sse2neon`.
- The pinned RT64 CMake has Linux ARM64 DXC support.
- Wave Race's frontend CMake currently hardcodes RT64's x64 Linux DXC;
  `patches/0001-arm64-linux-dxc.patch` changes only that selection.
- RT64's SDL Vulkan window path is enabled with
  `RT64_SDL_WINDOW_VULKAN=ON`.
