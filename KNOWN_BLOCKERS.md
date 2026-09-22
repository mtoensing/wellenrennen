# Known blockers and proven facts

This file exists to prevent repeated investigation. Record only reproduced facts.

## 2026-09-22 — ROM-free upstream target build is not a valid ARM64 gate

GitHub Actions runs #1 and #2 reached native aarch64 Clang compilation, then
failed in `src/main.cpp` because the pinned upstream source includes
`ultramodern` / `librecomp` headers unconditionally while the CMake target
does not expose those include directories when
`WR64_WITH_RUNTIME=OFF`.

Observed failure:

```
include/wr64/callbacks.h:5:10:
fatal error: 'ultramodern/ultramodern.hpp' file not found
```

This is not evidence that ARM64 is unsupported.

Do not spend time trying to make the upstream phase-00 executable build unless
that becomes necessary for the real port. The repository CI should use smaller
ROM-free architecture/dependency probes instead.

## ARM64 RSP path exists upstream

Pinned N64ModernRuntime selects `sse2neon.h` when
`__aarch64__` / `_M_ARM64` is defined.

Treat a failure compiling that ARM64 header path as a real dependency/toolchain
blocker.

## Linux ARM64 DXC selection

Pinned RT64 has logic for Linux ARM64 DXC.

The Wave Race top-level frontend CMake currently re-declares DXC with a hard
coded Linux `x64` path. The repository contains:

`patches/0001-arm64-linux-dxc.patch`

Apply that patch to the pinned Wave Race source for a full ARM64 frontend build.
Do not patch RT64 for this specific issue.

## Full binary requires the user's ROM

The complete executable cannot be produced from public CI alone because
`RecompiledFuncs/` is generated from the user's Wave Race 64 USA Rev A ROM.

Required SHA-1:

`508dfc2d4caa42b6f6de5263d0aed5e44ac7966a`

Never commit the ROM or generated ROM-derived files to make CI pass.

## Real-device Vulkan status

Not yet proven.

This is the highest-value device gate:

Can pinned RT64 create and present through Vulkan on the RG40XX H / H700 /
Mali-G31 MP2 under KNULLI?

Run:

`bash scripts/probe-rg40xx.sh`

before inventing graphics workarounds.

## Performance

No RG40XX H performance result exists yet for this port.

Do not claim 60 FPS. First prove that a race sustains the game's native
approximately 30 Hz simulation rate. Then test RT64 60 FPS presentation.
