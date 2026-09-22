# Wellenrennen — PortMaster ARM64 bring-up

Do not restart broad research. The goal is a working PortMaster prototype of
Wave Race 64: Recompiled on the real RG40XX H test device.

Do not optimize, refactor, redesign or prepare a PortMaster PR before the game
actually runs on the hardware.

## Goal

Create/use:

`mtoensing/wellenrennen`

Work on:

`prototype/rg40xx`

Bring the pinned Wave Race 64: Recompiled source to PortMaster as a native
aarch64 build and run it on the real Anbernic RG40XX H.

The initial success criteria are:

1. build for aarch64
2. RT64 creates a working Vulkan surface
3. game boots
4. menu works
5. controller works
6. audio works
7. one race is playable
8. game logic holds its intended 30 FPS during a race
9. only then test 60 FPS presentation/interpolation

A locked 60 FPS presentation is a stretch goal, not a bring-up requirement.

Wave Race itself runs race simulation at 30 Hz. RT64 may present interpolated
frames at 60 Hz. Never change game logic timing in an attempt to reach 60 FPS.

## Fixed test system

Use exactly this test system unless instructed otherwise:

- Device: Anbernic RG40XX H
- Firmware: KNULLI
- SoC: Allwinner H700
- CPU: 4× Cortex-A53, up to about 1.5 GHz
- Architecture: aarch64
- GPU: Mali-G31 MP2
- RAM: 1 GB
- Display: 640×480
- SSH host: `192.168.178.76`
- SSH user: `root`
- SSH port: `22`
- KNULLI default root password: `linux`
- If that password fails:
  `System Settings -> Security -> Root password`
- SSH must be enabled:
  `System Settings -> Services -> SSH`
- Persistent storage: `/userdata`
- PortMaster path: `/userdata/roms/ports`
- Game path: `/userdata/roms/ports/wellenrennen`

Use the same SSH/deploy workflow as the Sternenfuchs prototype.

## Upstream

Primary source:

`https://github.com/elliotttate/wave-race-64-recomp`

Initial pinned source revision:

`9041cc8024f6d2015859f88f5a0307b36cd4e50a`

Pinned submodules at that revision:

- N64ModernRuntime:
  `cdf5abbd5026fef5c364c676e4667c45e42b6863`
- RT64:
  `5473732a822a4423b5696e7cb18fecc425a59875`
- RecompFrontend:
  `b1a1477c6556aeb7ed45defbfb5924f721efebc1`

Put these revisions in `scripts/versions.sh`.

Do not update upstream revisions during initial bring-up.

## Required ROM

The current upstream build targets:

**Wave Race 64 (USA) (Rev A)**

Also called:

**USA v1.1 / revision 1**

Expected properties:

- format: `.z64`
- size: 8 MiB
- cartridge ID: `WR`
- region: `E`
- revision: `1`
- header CRC:
  `0x492F4B61 0x04E5146A`
- SHA-1:
  `508dfc2d4caa42b6f6de5263d0aed5e44ac7966a`

Do not use:

- USA v1.0
- Japanese release
- European release
- Shindou edition

Important: some older upstream planning documentation still discusses USA v1.0.
That information is stale for the current source tree.

For ROM compatibility, trust the current upstream `README.md`,
`docs/BUILDING.md` and the ROM identification/generation tools.

Never commit:

- ROM files
- ROM extracts
- generated disassembly
- generated ELF files
- `RecompiledFuncs/`
- other ROM-derived intermediate files

Add all of them to `.gitignore`.

## Important architectural difference from Sternenfuchs

Sternenfuchs can build its runtime without possessing the Star Fox ROM.

Wave Race 64: Recompiled cannot produce the complete game binary from a clean
checkout alone.

Its build pipeline uses the user's Wave Race ROM to generate the statically
recompiled game code under `RecompiledFuncs/`.

Therefore:

### Public CI

Public GitHub Actions must never require or contain the ROM.

CI may validate:

- repository structure
- ARM64 toolchain
- dependency configuration
- patches
- non-ROM build stages
- PortMaster packaging
- shell scripts
- architecture probes

Do not commit generated game code merely to make CI green.

### Full ARM64 build

The complete ARM64 game build must run in an ephemeral environment that has
access to the user's legally obtained ROM.

The ROM and generated files must remain outside git.

If GitHub Actions cannot receive the ROM securely, do not invent a workaround
that places copyrighted data in the repository.

Build locally/on an authorized ARM64 build environment instead.

## Compiler

Use Clang.

Do not use GCC for the generated game code.

Upstream explicitly warns that modern GCC optimization has produced incorrect
N64Recomp output.

Use approximately:

- Clang 15+
- CMake 3.20+
- Ninja
- Python 3.10+
- MIPS binutils
- optimized build

Start with:

`RelWithDebInfo`

Do not benchmark Debug builds.

Once the build is correct, Cortex-A53-specific optimization may be tested with:

`-mcpu=cortex-a53`

Do not add aggressive optimization flags before the unmodified optimized build
works.

## ARM64 specifics

N64ModernRuntime already contains an aarch64 path for the RSP vector code via
`sse2neon`.

Do not rewrite the RSP implementation merely because upstream documentation
mentions SSSE3/SSE4.1 on x86.

Verify the existing ARM64 path first.

The Wave Race top-level CMake currently contains Linux frontend shader compiler
logic that assumes the x64 DXC binary.

RT64 itself already distinguishes Linux x64 and Linux ARM64 DXC binaries.

If ARM64 configuration fails because Wave Race selects:

`dxc/bin/x64/dxc-linux`

patch only the Wave Race build logic so Linux aarch64 selects RT64's:

`dxc/bin/arm64/dxc-linux`

and corresponding ARM64 library path.

Do not patch RT64 for a problem that exists only in Wave Race's surrounding
CMake code.

## Graphics

RT64 is the largest technical risk on the RG40XX H.

Initial target:

- Linux aarch64
- KNULLI
- SDL2
- Vulkan
- 640×480
- fullscreen
- 4:3
- original textures
- original water
- no HD texture pack
- no modern/high water
- no MSAA
- no unnecessary post-processing
- no replacement texture enhancements
- no expensive graphical effects

Use RT64's SDL Vulkan window path where appropriate:

`RT64_SDL_WINDOW_VULKAN=ON`

The initial PortMaster prototype must not depend on:

- X11
- desktop compositors
- bundled Mesa
- bundled Mali drivers
- bundled Vulkan loader when the CFW already provides the required loader
- Weston unless device evidence proves it is necessary

First determine what KNULLI already exposes.

Do not begin by replacing the graphics stack.

## Device Vulkan gate

Before spending time on game-specific runtime bugs, verify the real device.

The device smoke script must record at least:

- `uname -a`
- architecture
- available SDL2
- available Vulkan loader
- available Mali/Vulkan ICD files
- `/dev/dri` state if present
- binary `file` output
- `ldd` output

If `vulkaninfo` exists, capture a short Vulkan capability summary.

If it does not exist, do not install random system packages onto KNULLI merely
to get `vulkaninfo`.

A successful ARM64 compile does not prove the game can run.

The critical first runtime gate is:

**Can RT64 create a Vulkan device and present a frame through the KNULLI graphics stack?**

If not, stop and diagnose that exact failure before touching gameplay code.

## SDL and system libraries

Follow PortMaster rules.

Do not bundle:

- SDL2
- libc
- libstdc++
- libpthread
- librt
- Mesa
- libGL
- libEGL
- libGLX
- Mali drivers
- Vulkan drivers

Use the CFW-provided libraries wherever possible.

Bundle only libraries that `ldd` and real-device testing prove are missing and
safe to distribute.

Do not copy an Ubuntu library directory into the port.

## PortMaster

Prototype location:

`/userdata/roms/ports/Wellenrennen.sh`

Game directory:

`/userdata/roms/ports/wellenrennen/`

Launcher must use PortMaster's normal:

- `control.txt`
- `get_controls`
- `$ESUDO`
- `pm_platform_helper`
- `pm_finish`

Do not hardcode KNULLI-specific behavior into the final launcher unless a real
device bug requires it.

Device-specific experimentation may live in the smoke/development scripts.

The shipped launcher should remain as CFW-agnostic as practical.

Do not submit a PortMaster PR during initial bring-up.

Before any eventual PortMaster PR, read the current:

`PortsMaster/PortMaster-New/AGENTS.md`

and expand testing beyond this single KNULLI device.

## Controller

Prefer native SDL controller input through RecompFrontend.

Do not implement keyboard/controller translation hacks until native gamepad
input has actually failed on hardware.

Wave Race is unusually sensitive to analog-stick response.

Do not silently convert the analog stick to digital input.

Verify:

- steering
- acceleration
- braking
- Start
- menu navigation
- exit-to-frontend behavior

Do not tune analog curves until basic native input works.

## Audio

Audio uses the recompiled RSP microcode.

The ARM64 path must be tested rather than replaced preemptively.

Bring-up order:

1. boot without considering audio performance
2. verify RSP audio code builds on ARM64
3. verify SDL audio opens
4. verify music/effects during an actual race

Do not disable audio permanently merely to make the game boot.

A temporary diagnostic no-audio mode is acceptable only to isolate a crash.

## Performance

Do not chase 60 FPS before correctness.

Measure these separately:

### Game rate

During a race Wave Race should sustain approximately:

`30 game frames/s`

This is the important gameplay-performance threshold.

### Presentation rate

RT64 may interpolate presentation to:

`60 FPS`

The game simulation must remain at its original rate.

Initial performance ladder:

1. stable game logic at 30 FPS
2. stable rendering without interpolation problems
3. enable 60 FPS presentation
4. measure frametime
5. only then optimize

If the machine cannot sustain the game's native 30 Hz race rate, disable
optional rendering features before changing game code.

## Initial graphics/performance configuration

Use the lowest-risk configuration first:

- resolution: 640×480
- aspect ratio: 4:3
- water: Original
- textures: Original
- custom music: Off initially if useful for isolation
- MSAA: Off
- presentation target: 30 during first gameplay validation
- VSync: test both only if required
- additional enhancements: Off

Once a full race works correctly:

1. enable 60 FPS RT64 presentation
2. measure whether game rate remains 30
3. measure presentation stability
4. only then re-enable optional enhancements one at a time

Do not use HD textures or modern water while diagnosing baseline performance.

## Repository structure

Use approximately:

```text
.github/
  workflows/
    build-arm64.yml

patches/

portmaster/
  wellenrennen/
    README.md
    Wellenrennen.sh
    port.json
    gameinfo.xml
    licenses/

scripts/
  versions.sh
  build-arm64.sh
  deploy-rg40xx.sh
  setup-ssh.sh
  smoke-rg40xx.sh
  fetch-rg40xx-log.sh

AGENTS.md
README.md
SOURCES.md
.gitignore
```

Do not copy historical debugging files into the final PortMaster package.

## Scripts

Implement the same development workflow used for Sternenfuchs:

### `scripts/setup-ssh.sh`

Configure key-based access to:

`root@192.168.178.76`

Do not store the password in git.

### `scripts/build-arm64.sh`

Build the ARM64 prototype.

Requirements:

- pinned source
- pinned submodules
- Clang
- optimized build
- reproducible patches
- no ROM committed
- no ROM-derived generated files committed

### `scripts/deploy-rg40xx.sh`

Deploy to:

`/userdata/roms/ports/wellenrennen`

Preserve any user ROM already present.

Never delete `.z64` files during deployment.

### `scripts/smoke-rg40xx.sh`

Run diagnostics on the real device.

Initial smoke must determine:

1. binary architecture
2. dynamic dependencies
3. Vulkan availability
4. RT64 startup
5. ROM recognition
6. whether a window/frame can be presented
7. whether the process reaches the frontend/game

Do not call a timeout after successful startup a failure if the program was
deliberately left running.

Capture the actual reason for termination.

### `scripts/fetch-rg40xx-log.sh`

Fetch all relevant logs into:

`device-logs/`

Keep `device-logs/` ignored by git.

## Build / test loop

Work in this order:

1. Create/use `mtoensing/wellenrennen`.
2. Work only on `prototype/rg40xx`.
3. Pin upstream revisions.
4. Establish ARM64 non-ROM/toolchain build.
5. Verify ARM64 DXC selection.
6. Verify generated code compiles with Clang on aarch64.
7. Build the complete binary using the user's ROM outside git.
8. Package the minimum PortMaster prototype.
9. Deploy to the RG40XX H.
10. Run device smoke.
11. Fetch logs.
12. Fix only the smallest observed blocker.
13. Repeat.
14. Reach the menu.
15. Verify controller.
16. Verify audio.
17. Start one race.
18. Verify approximately 30 Hz game rate.
19. Finish one race.
20. Test RT64 60 FPS presentation.
21. Measure performance.
22. Only after that consider optimization or broader CFW support.

## Do not do these first

Do not begin with:

- HD textures
- modern/high water
- replacement soundtrack
- haptics
- widescreen
- 16:9
- 720p
- shaders/effect tuning
- PGO
- LTO experiments
- CPU governor hacks
- overclocking
- custom Mesa
- custom Mali blobs
- Weston
- broad refactoring
- dependency upgrades
- upstream rebases
- PortMaster PR preparation

They are irrelevant until baseline gameplay works.

## Debugging rule

Fix evidence, not hypotheses.

When blocked:

1. read the exact error
2. inspect only the relevant upstream code
3. make the smallest patch
4. rebuild
5. rerun on hardware
6. compare logs

Do not create compatibility layers preemptively.

Do not replace an upstream subsystem merely because it looks difficult.

## Success definition

The first prototype is successful when the real RG40XX H can:

- launch Wellenrennen from KNULLI's Ports menu
- load the user's supported Wave Race 64 USA Rev A ROM
- display the game correctly at 640×480
- navigate menus with the built-in controls
- play audio
- enter a race
- steer normally with analog input
- complete a race
- maintain correct game speed

Stable 60 FPS interpolated presentation is an additional performance goal.

It is not required for the first functional prototype.

## Status replies

Keep implementation status concise:

```text
Build: PASS/FAIL — <one line>
Deploy: PASS/FAIL — <one line>
Vulkan: PASS/FAIL — <one line>
Device: PASS/FAIL — <one line>
Game rate: <measured value or not tested>
Presentation: <measured value or not tested>
Changed: <files/commit>
Next: <single next action>
```
