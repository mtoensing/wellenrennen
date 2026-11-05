# GLES frame synthesis on RG40XX H

The pinned recompilation and its game timing stay unchanged. The experiment
reuses the working GLideN64/GLES renderer rather than rerendering its thousand
plus draw calls for every intermediate frame.

`renderer/Wr64FrameSynth.h` is copied into the GLideN64 work tree by the full
build script. The plugin patch intercepts native swaps and polls presentation
on the GL worker. Wave Race passes the cartridge's frame divider to the plugin.

The GPU pipeline captures two completed images, filters them to 80x60, estimates
block motion at 40x30, synthesizes a 320x240 scene, then scales it to the 640x480
panel with the native HUD. Color guidance and per-pixel mismatch rejection limit
motion leaking between the rider and water. This is optical-flow frame
generation with possible occlusion/foam artifacts, not RT64 geometry
interpolation. It adds approximately one native-frame interval of display
latency. 30+ Hz UI modes remain native.

## Device tests

```
# Existing optimized Clang build and package workflow; ROM remains private.
WR64_ROM=/path/to/own-ROM.z64 bash scripts/build-arm64-docker.sh full
bash scripts/package-arm64.sh
bash scripts/deploy-rg40xx.sh

# No image dumps during stability tests.
SYNTH_GPU_MAX=1 bash scripts/bench-synth-rg40xx.sh

# Separate diagnostic run, not a stability measurement.
SYNTH_GPU_MAX=1 SYNTH_DUMP=1 SYNTH_DUMP_AT=55 bash scripts/bench-synth-rg40xx.sh
```

The prototype launcher enables `WR64_FRAME_SYNTH=1` by default. Set it to `0`
for a baseline launch. On H700 only, the launcher temporarily requests the
highest operating point advertised by the CFW (and respects an existing maximum
limit), restoring the old GPU minimum when the launcher exits. Other SoCs keep
their existing policy; they are untested.

The benchmark signals the game, keeping the launcher and `tee` alive for clean
shutdown/cache persistence. It resumes EmulationStation and restores its GPU
minimum. `SYNTH_SECONDS` controls duration. Snapshot and GPU-query modes are
optional diagnostics and must not be mistaken for physical presentation proof.

For an independent front-buffer check, build `scripts/fb-sample.c` with the
ARM64 build container, copy it to `/tmp` and run during a moving race:

```
FB_SAMPLE_VSYNC=1 /tmp/wr64-fb-sample 10
```

This hashes the front page at panel VBlanks. Do not save full images during that
measurement: the full framebuffer reads and writes delay the sampler.
The panel's observed nominal-60 cadence is approximately 59.7 Hz. Compare native
rate, actual swaps and distinct front-buffer images; repeated images alone do
not establish interpolation. Full-size GPU dumps of sources/motion/phases are
used separately to inspect artifacts. See `KNOWN_BLOCKERS.md` for current facts.

## Measured outcome

The final 13 ms work window was tested through the regular launcher with its
own H700 clock handling. During the moving-race measurement the cartridge
continues at about 20 game frames/s, with 59.71–59.72 swaps/s. A separate
RGB-only VBlank sampler observed 897 distinct images in 15.007 seconds
(59.773/s); median interval 16.746 ms, p95 16.867 ms, maximum 18.862 ms and no
interval over 25 ms. Exact ignored log paths are in `KNOWN_BLOCKERS.md`.

This validates nominal-60 presentation in that measured section. It does not
establish every track, cold loading or a correctly completed full course.
Native 30 Hz UI/results bypass the generator. The game, launcher and clock
policy returned cleanly to EmulationStation after the test.
