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

## 2026-09-22 — full aarch64 build boots to the title screen on the device

Build (Docker, Ubuntu 22.04, Clang 18, libstdc++ 12, SDL 2.30.9), proven:

- `generate_game.py` from the verified ROM: all 21 code sections of the
  assembled ELF match the ROM byte for byte; N64Recomp + RSPRecomp succeed.
- Fixes needed on Linux/aarch64 (all in `scripts/build-arm64.sh` / `patches/`):
  SDL >= 2.26 (`SDL_GetWindowSizeInPixels`); missing `<cstddef>`/`<string>`
  under libstdc++ 12; `SDL2_INCLUDE_DIRS` (upstream only runs
  `find_package(SDL2)` on Apple); `PLUME_SDL_VULKAN_ENABLED` must be global
  (RT64 only sets it in its own directory, RecompFrontend then sees plume's
  X11 `RenderWindow`); `NFD_PORTAL=ON` (no GTK 3 on the CFW);
  `SDL_WINDOW_VULKAN` on the Linux window (patch 0003; without it
  `SDL_Vulkan_CreateSurface` fails "The specified window isn't a Vulkan
  window" and the process segfaults).

Device runs through the real launcher (Westonpack `drm gl kiosk llvmpipe`):

- With the bundled replacement soundtrack the runtime printed
  `Failed to allocate memory!` (librecomp's 512 MiB RDRAM `mprotect`; device
  `overcommit_memory=0`, no swap, the soundtrack is decoded fully into RAM).
  Packaging without `assets/music` and `assets/textures` fixes it.
- Then: Lavapipe device, RG40XX-H controller detected, audio device opens,
  game state reaches `TITLE_SCREEN`, original music is audible
  (`[wr64] audio is audible`).
- But: `the game is running at 0 frames per second (it asked for 20)`, two
  cores at 100 %, and `/dev/fb0` shows only a black Xwayland window
  (with title bar) at 30/60/100 s. No rendered frame proven yet.
- After that 150 s run was stopped, the device stopped answering ping/SSH
  for more than 20 minutes. Cause not determined (no logs could be fetched).

## 2026-09-23 — RT64 on Lavapipe never presents; GLideN64 on GLES works

- RT64 blocks every frame on `shaderUber->waitForPipelineCreation()`
  (`hle/rt64_state.cpp`) until eight ubershader pipelines are compiled.
  Under Lavapipe on 4x A53 this did not finish in 15 minutes (six
  `Gfx_Thread` compile threads + four `llvmpipe` threads busy, black screen,
  `the game is running at 0 frames per second`). Software Vulkan is not a
  viable path on this device. No PortMaster port uses RT64 or Lavapipe;
  N64 ports there (Ship of Harkinian, 2Ship2Harkinian, Starship) render with
  GL/GLES.
- Replacement renderer (patch 0004): GLideN64 (pinned in `versions.sh`),
  built as its mupen64plus plugin with `-DEGL=ON -DUSE_SYSTEM_LIBS=ON`,
  driven by a `GLideN64Context` implementing ultramodern's `RendererContext`
  and selected with `WR64_RENDERER=gliden64`. The mupen64plus core API it
  needs (Config*, VidExt_*) lives in `libwr64_m64pcore.so`, loaded
  `RTLD_LOCAL`: exporting those names from the executable crashed, because
  GLideN64 has global function-pointer variables with the same names and the
  executable's symbols interposed them (SIGSEGV in `PluginStartup` storing
  into our read-only text).
- The RecompFrontend launcher only runs its auto-start callback from its
  RT64-drawn UI; in GLideN64 mode the game is started directly.
- Result on the RG40XX H through the real launcher, with KNULLI's own SDL2
  (mali video driver) and no Westonpack/Mesapack: `OpenGL ES 3.2 ... Mali-G31`,
  `renderer ready`, audio open and audible, state `TITLE_SCREEN`, 59.7 screen
  updates/s, title screen visible in `/dev/fb0`
  (`docs/evidence/2026-09-23-title-screen-gliden64-gles.png`).
- Audio over SSH needs EmulationStation's environment (`XDG_RUNTIME_DIR=/var/run`);
  without it SDL's ALSA open fails with "Host is down". The smoke script
  imports it; a launch from the Ports menu already has it.

## 2026-09-23 — game stalled after 4 frames: VI updates starved the game's display list

- Symptom (GLES renderer): title screen drawn, then `0 frames/s`; game
  scheduler (`Main_Thread`, decomp `src/game/main.c`) stuck in state 1 /
  busy 1 waiting for an SP-done (0x17).
- Trace (`n64modernruntime-9001-sched-trace.patch`,
  `ULTRAMODERN_SCHED_TRACE=1`): the 5th graphics task was enqueued
  (`enqueue ok=1`) but never dequeued by the gfx thread; the gfx action
  queue grew steadily (34, 35, 36, 37 ...). ultramodern's VI thread enqueues
  a `ScreenUpdateAction` every VI (60 Hz); presenting through
  GLideN64/SDL/Mali took slightly longer than a VI, and moodycamel's
  multi-producer dequeue prefers the producer with the most items, so the
  single `SpTaskAction` from the game thread was starved forever.
- Fix (patch 0004): `GLideN64Context::update_screen` presents only when the
  VI origin changed (a new game frame), so the gfx thread keeps up.
- Result on the RG40XX H (race input script, lowest settings): title ->
  main menu -> rider select -> course overview -> race -> race results;
  menus 12-20 of the requested 20 frames/s, 17-20 frames/s in the race,
  29 of 30 on the results screen. Screenshots:
  `docs/evidence/2026-09-23-race-gliden64.png`,
  `docs/evidence/2026-09-23-race-results-gliden64.png`.

## 2026-09-23 — race performance with GLideN64 (lowest settings)

`scripts/bench-race-rg40xx.sh` (race input script, 5 s windows):

- Default (single-threaded GLideN64): 17-18 frames/s in the race; the
  render thread (`Gfx_Thread`, GLideN64 HLE + GL) at 100 % of one core, game
  logic threads < 10 %.
- `ThreadedVideo = True` (now the default in `gliden64.ini`): 20.0 frames/s
  in the race = the rate this race requests ("it asked for 20"); render
  thread ~87 % + GL thread ~25 %.
- No gain / worse, not adopted: `EnableHWLighting = True` (same),
  `EnableFBEmulation = False` (10-13 frames/s), GLideN64 with LTO
  (`USE_IPO=ON`, render thread 883 vs 874 ticks/10 s).
- Menus and the race start still dip to 12-17 frames/s; parts of the game
  that request 30 frames/s will not reach it with ~13 % render-thread
  headroom.
