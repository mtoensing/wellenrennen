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

## 2026-09-22 — RG40XX H/KNULLI graphics probe

Real device:

- Anbernic RG40XX H
- KNULLI / Batocera 42
- kernel 4.9.170
- aarch64
- 973 MiB RAM
- no swap
- proprietary Mali kernel module loaded: `mali_kbase`
- device node present: `/dev/mali0`
- aarch64 SDL2 present
- Vulkan ICD present:
  `/usr/share/vulkan/icd.d/mali_icd.json`
- ICD points to:
  `/usr/lib/libmali.so`
- ICD reports Vulkan API:
  `1.0.108`
- `vulkaninfo` is not installed
- `libvulkan.so` / `libvulkan.so.1` was not found by the initial probe
- PortMaster control file:
  `/userdata/system/.local/share/PortMaster/control.txt`

This is promising: the Mali Vulkan driver is installed. The remaining loader
question is important because pinned RT64 uses Volk, and pinned Volk calls
`dlopen("libvulkan.so.1")` then `dlopen("libvulkan.so")` on Linux.

Next device gate:

1. inspect `/usr/lib/libmali.so`
2. check whether it exports `vkGetInstanceProcAddr`
3. if yes, prefer the smallest RT64/Volk integration needed to load the existing
   system Mali driver; do not bundle or replace the Mali driver
4. if no, locate an existing PortMaster/CFW Vulkan loader solution before
   considering any bundled loader

Do not interpret the missing `vulkaninfo` command as a Vulkan failure.


## 2026-09-22 — Mali ICD is not the Vulkan loader

The real-device probe can `dlopen("/usr/lib/libmali.so")`, but direct lookup of
`vkGetInstanceProcAddr`, `vkCreateInstance` and
`vkEnumerateInstanceExtensionProperties` fails.

That is compatible with `libmali.so` being an ICD rather than the system
Vulkan loader. The ICD JSON already points the loader to this library.

Next checks:

- search `/usr/lib64` and `/lib64` for `libvulkan.so*`
- test ICD exports:
  - `vk_icdGetInstanceProcAddr`
  - `vk_icdNegotiateLoaderICDInterfaceVersion`
- if the loader is truly absent, provide only a Vulkan loader compatible with
  the installed ICD; do not replace or bundle the Mali driver
