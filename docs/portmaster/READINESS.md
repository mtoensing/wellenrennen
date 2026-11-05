# PortMaster submission preparation

This is a local candidate, not an upstream submission or a redistribution clearance.

Checked sources:
- PortMaster-New `AGENTS.md`, template and public tooling at `3151d6529a8f2d5f649851d4b152f60f8f1d300d`.
- PortMaster-GUI helpers, metadata loading and hardware capability matching at `9ed29285ecbb0610b7c86a0b77d0d9d1c74efd49`.
- [Packaging guide](https://portmaster.games/packaging.html).

## Remaining gates

1. **Source and licenses:** the pinned upstream notices identify an absent RecompFrontend license. This candidate instead uses upstream's existing `WR64_WITH_FRONTEND=OFF` path and excludes its libraries and PC UI assets. Link-command and symbol checks confirmed their absence. The package carries the supplied native dependency notices and a pinned source/build reference. Human review of the submission, including its source and license notices, remains necessary.
2. **Testing:** only RG40XX H/KNULLI at 640x480 is available. The other CFW/driver/device entries stay unchecked in the PR text, as requested by the owner. PortMaster's current guidance says a submission focused exclusively on one device will be rejected. Manual analog steering/braking/exit and a correctly completed full course also remain unverified by these automated tests.
3. **Contributor review:** the AI-assisted authorship checkbox belongs to the human submitter; it is deliberately unchecked.

## Local candidate

```sh
python3 scripts/prepare-portmaster.py
python3 scripts/check-portmaster.py .work/PortMaster-New/ports/wellenrennen
```

The candidate uses the validated private distribution ZIP and pinned build volume. It strips debug information, verifies each ELF `.text` section is unchanged, collects provided native dependency license texts, removes development tests, and applies the catalogue layout. It never uploads files. `--replace` only replaces this generated candidate and refuses to delete any ROM found there.

The original development launcher stays executable; the PortMaster candidate is mode 0644 by upstream convention. The port keeps its CFW-provided SDL2, EGL/Mali and core libraries. Minimum glibc is 2.34; the current executable also needs GLIBCXX_3.4.30. Other CFW library compatibility must be tested, not supplied by bundling libstdc++.

The screenshot is a real gameplay capture. The upstream self-hosted PR-check script is not public in this checkout; local checks use the public metadata, large-file and gameinfo tooling and must not be described as a completed GitHub PR CI run.

## Preparation result (2026-11-05)

Public `build_release.load_port`, `build_gameinfo.parse_gameinfo` and
`build_data.load_port` checks pass for this candidate, together with local
ELF/architecture, forbidden-library/ROM, size, LF/0644 and screenshot guards.
The stripped executable is 11,304,680 bytes. `.text` hashes are unchanged by
packaging. The candidate contains no ROM or generated source files.

The no-frontend binary passed the bounded hardware test recorded above. A
follow-up using only the reduced `assets/water` payload could not start because
SSH to the device timed out/returned host down. No device files were changed
by that attempt. Recheck that exact catalogue payload when the device returns.
The previous hardware test still had the older asset directory available.
