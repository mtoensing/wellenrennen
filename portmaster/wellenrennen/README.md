## Wellenrennen

Experimental PortMaster/aarch64 port of
[Wave Race 64: Recompiled](https://github.com/elliotttate/wave-race-64-recomp)
for the Anbernic RG40XX H under KNULLI.

### ROM

Copy your own **Wave Race 64 (USA) (Rev A)** `.z64` ROM into
`ports/wellenrennen/`. SHA-1: `508dfc2d4caa42b6f6de5263d0aed5e44ac7966a`.
Other revisions are unsupported by this pinned recompilation. No ROM or
extracted game assets are included; the executable contains statically
recompiled game code and still requires your ROM at runtime.

### Graphics and timing

The port uses the CFW's SDL2 and OpenGL ES with GLideN64. Original water,
textures and music; native scene resolution, 4:3, no MSAA or texture packs.

The new presentation path targets the panel's nominal 60 Hz using GPU optical
flow. Race simulation stays at the original rate (20 Hz in the tested mode).
Scene pixels are synthesized at 320x240 and composed at 640x480; HUD text stays
native. This adds roughly one game-frame interval of display latency and can
produce artifacts at foam, occlusions or rapid movement. It is image-space
frame generation, not RT64 geometry interpolation. Native 30 Hz UI/results
modes bypass it to preserve their correct speed.

On H700, the launcher temporarily requests the CFW's highest advertised GPU
operating point, within any existing maximum limit, and restores the previous
minimum on exit. No driver, firmware, governor or overclock is installed.
`WR64_FRAME_SYNTH=0` disables the new path for a baseline development launch.

### Status

Hardware tests reach menus, an automated championship race and the results
screen with non-silent audio output. The automated route can be disqualified;
it is not proof of a correctly completed full course. Short sections reach the
nominal 60 Hz panel cadence with the original game rate. Check the repository's
`KNOWN_BLOCKERS.md` for final measurements and remaining limitations. Other
hardware/CFWs and manual full-race control verification are outside these tests.

Exit with the normal PortMaster hotkey so the renderer can save its shader
cache. Initial shader compilation/loading can stutter.
