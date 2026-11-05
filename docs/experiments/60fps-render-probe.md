# RG40XX H: 60 Hz renderer feasibility

The owner's 2026-11-05 instruction prioritizes 60 Hz presentation and permits
renderer rewrites. Preserve the cartridge's simulation timing. Keep the existing
pinned source/decomp revisions and the stock CFW graphics stack.

## Reproduce

Build with the existing full ARM64 workflow, then package/deploy. The patch
series adds optional diagnostics; ordinary launches keep the baseline renderer.

```
bash scripts/probe-render-rg40xx.sh
PROBE_MODE=commands bash scripts/probe-render-rg40xx.sh
```

Both runs use the existing automated menu/race route, leave menus unmodified
for the first 45 seconds, run for 80 seconds, and save logs under `device-logs/`.
The script pauses EmulationStation and resumes it on exit. Exit 124 means the
bounded run was deliberately terminated, not a startup failure.

* `hle`: three complete `ProcessDList` passes before DP completion, followed by
  a synchronous GL-worker/GPU barrier. This includes N64 command interpretation
  and geometry processing. No post-DP display-list replay is used.
* `commands`: one normal HLE pass records asynchronous GL commands and owns
  copies of ring-buffer upload data, then two immediate GL-worker replays with
  GPU completion. Pooled command objects remain reserved until both replays
  finish; upload copies are keyed by allocation serial, not ring-buffer offset.
  Resource deletion or an excessive command count rejects replay.

The command probe is a frozen-scene throughput experiment, not interpolation.
It does not prove GL state equivalence, animated water correctness, presentation
pacing, or full gameplay at 60 Hz. Replayed state/resource changes require
further auditing before retaining a command list across game frames. Synchronous
queries/resource creation execute only in the original pass. Neither test
includes two additional display swaps, nor vertex interpolation overhead.

A low cached-render time is a necessary direction for further work, not proof
of a complete 16.67 ms frame budget. Report race-state log lines with timings;
menu timings cannot establish race performance. Do not interpret the upstream
"presenting at 30" configuration log as measured physical presentation.

## Scope

No new decomp fork is required for these tests: the current recomp already uses
the pinned LLONSIT decomp for generation. The experiments change renderer code,
which is kept as reviewable patches against Wave Race and GLideN64. No generated
sources, game assets, ROM or new binary are committed to this repository.

## Hardware result, 2026-11-05

| Measured operation | Time |
| --- | --- |
| Full HLE render, triple batch | 61.010–73.970 ms/render |
| Cached GL replay, two passes | 67.386–80.957 ms/render |
| Cached replay omitting draws, two passes | 4.788–8.249 ms/pair |
| Empty GPU barrier | 0.014–0.043 ms |

The six valid profiled replay samples contain 1,080–1,183 draw-array calls per
frame. One unsafe frame was skipped, not counted as a zero-cost render. See
`KNOWN_BLOCKERS.md` for exact ignored log paths and limitations. All timing
samples are sparse diagnostic samples, not median/p99 frametime distributions.

The tested unchanged command stream is too expensive for 60 Hz even with HLE
removed. A future geometry-based renderer must substantially reduce the draw
work and validate materials, blending, depth and animated water. A different
decomp repository alone would not remove this graphics workload. Screen-space
frame synthesis would be a separate, untested alternative with its own visual
accuracy and latency costs.
