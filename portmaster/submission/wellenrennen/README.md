## Notes

Thanks to [Elliott Tate and contributors](https://github.com/elliotttate/wave-race-64-recomp), [N64Recomp](https://github.com/N64Recomp), [GLideN64](https://github.com/gonetz/GLideN64), and [LLONSIT's decompilation project](https://github.com/LLONSIT/Wave-Race-64). Original game by Nintendo EAD.

Put your **Wave Race 64 (USA) (Rev A)** `.z64` in `ports/wellenrennen/`.
Expected SHA-1: `508dfc2d4caa42b6f6de5263d0aed5e44ac7966a`.

Original water, textures and music. GLES rendering; no Vulkan runtime or bundled system/graphics libraries. Experimental optical-flow presentation targets nominal 60 Hz while preserving the game's original simulation rate. Loading can stutter and intermediate images can show artifacts. Native 30 Hz UI modes remain native.

Currently tested on RG40XX H/KNULLI at 640x480 only. A temporary H700 stock GPU minimum is restored on exit. Exit with the normal PortMaster hotkey to save the shader cache.

## Controls

Names below follow SDL's standard controller mapping supplied by the CFW.

| Input | Action |
|---|---|
| Left stick | Steering / menu selection |
| A | Acceleration / confirm (N64 A) |
| X | Brake (N64 B) |
| Start | Pause / menu confirm |
| PortMaster exit hotkey | Exit |

## Compile

Source, pinned dependencies and patches: [mtoensing/wellenrennen](https://github.com/mtoensing/wellenrennen/tree/prototype/rg40xx).

```sh
WR64_ROM=/path/to/own-USA-Rev-A.z64 bash scripts/build-arm64-docker.sh full
bash scripts/package-arm64.sh
```

The build uses `WR64_WITH_FRONTEND=OFF`; native SDL input and audio remain enabled.

ROM-derived generated sources stay outside git. The public CI is ROM-free.
