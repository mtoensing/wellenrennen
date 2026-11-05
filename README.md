# Wellenrennen

Experimental native ARM64 PortMaster port of
[Wave Race 64: Recompiled](https://github.com/elliotttate/wave-race-64-recomp)
for the Anbernic RG40XX H under stock KNULLI.

Start with `AGENTS.md` and `KNOWN_BLOCKERS.md`. Work stays on `prototype/rg40xx`.
The owner's current target is 60 Hz presentation while preserving the original
simulation timing. The tested race requests 20 game frames/s; the old blanket
30 Hz assumption was corrected by source inspection and device measurements.

Stock KNULLI's Mali library has no hardware Vulkan. The prototype uses the CFW's
SDL2/GLES with GLideN64. The GPU optical-flow path has reached nominal-60 presentation in a measured
moving-race section; see [the experiment](docs/experiments/gles-frame-synthesis.md).
There is no PortMaster submission or completed broad-device compatibility test.

ROM, generated `RecompiledFuncs/`, disassembly, ELF files and ROM-derived
intermediates must remain outside git. Public CI is ROM-free; complete builds
use the owner's supported USA Rev A ROM in the private ARM64 build volume.
