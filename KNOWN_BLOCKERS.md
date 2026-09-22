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

FAIL — the installed KNULLI Mali driver has no Vulkan implementation.
See "2026-09-22 — installed libmali has no Vulkan at all" below.

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


## 2026-09-22 — installed libmali has no Vulkan at all

Evidence from the real RG40XX H (KNULLI, kernel 4.9.170):

- `/usr/lib/libmali.so` -> `libmali.so.0.20.0` (44542232 bytes), identical
  copy in `/usr/lib64`; driver string `r20p0-01rel0`.
- kernel module `mali_kbase` version `r20p0-01rel0 (UK version 11.17)`;
  GPU identified as `arch 7.0.9` (Bifrost, Mali-G31).
- `nm -D --defined-only` on the device's `libmali.so.0.20.0` (copied to the
  host): 1376 exported symbols — 642 `gl*`, 109 `cl*` (OpenCL), 44 `egl*`,
  **0 `vk*`**. No `vk_icdGetInstanceProcAddr`,
  `vk_icdNegotiateLoaderICDInterfaceVersion`, `vkGetInstanceProcAddr` or
  `vkCreateInstance`.
- `grep -a` for `vk_icd`, `vkCreate`, `VK_KHR` in the blob: 0 matches.
- The library has `fbdev` strings and no `gbm`/`wl_display` strings: it is
  the fbdev GLES/EGL/OpenCL build of the blob.
- No `libvulkan.so*` anywhere on the rootfs; no `vulkaninfo`.
  KNULLI's own `/usr/bin/knulli-vulkan hasVulkan` prints `Vulkan not found`.
- `/usr/share/vulkan/icd.d/mali_icd.json` exists but points at this
  non-Vulkan blob; the JSON is stale and is not evidence of Vulkan support.

Conclusion: bundling only a Vulkan loader cannot help — there is no ICD for
it to load. RT64 at the pinned revision has no GL/GLES backend on Linux, so
the documented first runtime gate (RT64 creates a Vulkan device and presents
a frame) cannot pass on the stock KNULLI graphics stack.

Every remaining route replaces part of the graphics stack (a Vulkan-capable
Mali blob, or a GLES backend/translation layer for RT64), which AGENTS.md
forbids without an explicit decision. Stop here until that decision is made.

ROM on the device, verified:
`/userdata/roms/n64/Wave Race 64 - Kawasaki Jet Ski (USA) (Rev 1).z64`,
SHA-1 `508dfc2d4caa42b6f6de5263d0aed5e44ac7966a`.

## 2026-09-22 — Vulkan works on stock KNULLI through PortMaster runtimes

Constraint from the owner: the port must run on stock KNULLI on this test
device; nothing on the system may be changed; everything goes through
PortMaster. So the Vulkan path is software (Lavapipe) from PortMaster's own
runtimes, not a replacement Mali driver.

Proven on the RG40XX H:

- `harbourmaster runtime_check` installs `weston_pkg_0.2.squashfs`
  (Westonwrap 0.2.7.1) and `mesa_pkg_0.1.squashfs` (Mesa 24.3.0-devel,
  LLVM 19.1.2) into `PortMaster/libs/`.
- Mesapack ships `libvulkan_lvp.so` + `share/vulkan/icd.d/lvp_icd.aarch64.json`
  but **no Vulkan loader**, and Lavapipe additionally needs
  `libxcb-randr.so.0`, `libxcb-dri3.so.0`, `libxcb-present.so.0`,
  `libxcb-sync.so.1`, which neither runtime ships. With those four and the
  Khronos loader `libvulkan.so.1` (1.3.204, Ubuntu 22.04) on the library
  path, `vulkaninfo` reports `llvmpipe (LLVM 19.1.2, 128 bits)`,
  Vulkan 1.3.296, with `VK_KHR_xcb_surface`, `VK_KHR_xlib_surface`,
  `VK_KHR_wayland_surface`, `VK_EXT_headless_surface`.
- KNULLI's SDL2 (2.32.8) has only the `mali` video driver, no X11/Wayland,
  and `/dev/dri` does not exist (only `/dev/fb0`). A Vulkan surface therefore
  needs Westonpack: `westonwrap.sh drm gl kiosk llvmpipe` starts Weston +
  Xwayland rendered through crusty -> KNULLI SDL2/Mali GLES.
- `vkcube --width 640 --height 480` (X11/xcb WSI) inside that mode ran
  400 frames in about 5 s, exit code 0, and the rendered cube was read back
  from `/dev/fb0` (`docs/evidence/2026-09-22-vkcube-lavapipe-westonpack.png`).

Not yet proven: RT64 on Lavapipe, and its speed on 4x Cortex-A53.

Rejected for now: a Vulkan-capable Mali blob (Hardkernel RK3326
`r13p0_gbm_with_vulkan_and_cl`, same Mali-G31 MP2) — the official download is
behind a Cloudflare browser check, it is a GBM build while this device has no
`/dev/dri`, and its redistribution terms are unclear. Rockchip's current
`libmali-bifrost-g31-g24p0-*` exports no `vk*` symbols.
