## Wellenrennen

Experimental PortMaster/aarch64 packaging for
[Wave Race 64: Recompiled](https://github.com/elliotttate/wave-race-64-recomp).

This package never contains Nintendo ROM data.

### ROM

Copy your own legally obtained **Wave Race 64 (USA) (Rev A)** ROM into:

`ports/wellenrennen/`

Expected SHA-1:

`508dfc2d4caa42b6f6de5263d0aed5e44ac7966a`

Other revisions are not supported by the pinned recompilation.

### Prototype target

Initial hardware:

- Anbernic RG40XX H
- H700 / Cortex-A53
- aarch64
- Mali-G31 MP2
- 1 GB RAM
- KNULLI
- 640x480

Bring-up starts with the least expensive configuration: 4:3, original
textures, original water and no optional visual enhancements.

Wave Race runs its race simulation at 30 Hz. A later goal is RT64 presentation
at 60 FPS using interpolation without changing the game's simulation rate.

This is not yet a finished PortMaster submission.
