# Wellenrennen

PortMaster/aarch64 bring-up for
[Wave Race 64: Recompiled](https://github.com/elliotttate/wave-race-64-recomp),
initially tested on an Anbernic RG40XX H running KNULLI.

Start with `AGENTS.md`.

Prototype order:

1. ARM64 build
2. Vulkan/RT64 startup
3. boot/menu
4. controller
5. audio
6. one complete race at the game's native 30 Hz race rate
7. RT64 60 FPS presentation/interpolation

No Wave Race 64 ROM, generated `RecompiledFuncs/`, or other ROM-derived
intermediate belongs in this repository.
