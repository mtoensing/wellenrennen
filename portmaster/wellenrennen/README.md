## Wellenrennen

Experimental PortMaster/aarch64 port of
[Wave Race 64: Recompiled](https://github.com/elliotttate/wave-race-64-recomp).

This package contains no Nintendo ROM data. Like upstream's own Windows and
macOS releases, the executable contains game code statically recompiled from
the ROM; the game still needs your ROM at runtime.

### ROM

Copy your own legally obtained **Wave Race 64 (USA) (Rev A)** ROM (`.z64`)
into `ports/wellenrennen/`.

Expected SHA-1: `508dfc2d4caa42b6f6de5263d0aed5e44ac7966a`

Other revisions are not supported by the pinned recompilation.

### Renderer

Upstream renders with RT64, which needs Vulkan. The Mali GLES drivers of
H700 CFWs have no Vulkan, so this port renders through the
[GLideN64](https://github.com/gonetz/GLideN64) plugin on OpenGL ES 3 with the
CFW's own SDL2. Its settings are in `gliden64.ini` (native 320x240, no
anti-aliasing, threaded video). Original water, textures and music; no
rumble.

### Status

Tested on an Anbernic RG40XX H (H700, Mali-G31, 1 GB) with KNULLI:
menus, a full race and the results screen, with audio. Races and menus hold
the 20 frames/s the game requests once the shader cache is built (the first
session compiles shaders and stutters; exit with the hotkey so the cache is
saved). Short dips to 16-18 frames/s remain around the race start.
Not yet tested on other devices or CFWs.
