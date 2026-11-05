Title: New port: Wellenrennen (Wave Race 64: Recompiled)
Target: PortsMaster/PortMaster-New:main
Status: local draft; broader compatibility and human review remain open.

## Game Information
- **New Port for**: Wellenrennen (Wave Race 64: Recompiled)
- **URL**: https://github.com/mtoensing/wellenrennen
- Testing Thread URL: not started

Native aarch64/GLES port requiring the player's USA Rev A ROM. Uses CFW SDL2/graphics libraries; no ROM or extracted assets are included. Experimental optical-flow presentation preserves simulation timing. In a 15.007 s moving-race section on RG40XX H/KNULLI, 897 distinct RGB frames were observed (59.77/s) while the game held its requested 20 Hz. This does not establish all tracks or a correctly completed course.

The build uses the existing `WR64_WITH_FRONTEND=OFF` path: RecompFrontend, recompui, recompinput, RmlUi and PC UI assets are excluded. Link-command and symbol inspection confirm their absence. SDL input and original RSP audio remain enabled. Supplied dependency licenses and pinned source/build references accompany the payload.

**Open gates:** final reduced-asset package smoke test (device currently unreachable), broader CFW tests and manual full-course/controller/exit verification remain open. No binary has been uploaded for this submission.

## Authorship & Testing
- [ ] I wrote and understand this script/patch myself, or clearly marked which parts came from an AI assistant and reviewed them
- [ ] I can explain every non-standard line in my launch script

The renderer experiment, launcher additions and preparation tooling were AI-assisted. Human contributor attestation is pending. The only EXIT trap restores the temporary H700 GPU minimum; process/controller cleanup stays with `pm_finish`.

## Submission Requirements

### CFW Tests
- [ ] AmberELEC
- [ ] dArkOS
- [ ] muOS
- [x] Knulli — RG40XX H, H700/Mali-G31, stock driver, 640x480; bounded automated race tests
- ROCKNIX
  - [ ] Libmali
  - [ ] Panfrost
  - [ ] Adreno (Optional)

No additional device/CFW is available to the submitter at present; these entries are untested.

### Resolution Tests
- [ ] 480x320 (Optional)
- [x] 640x480
- [ ] 720x720 (Optional)
- [ ] Higher resolutions

## File Structure
One `ports/wellenrennen/` directory with metadata, a 640x480 gameplay screenshot, a 0644 launcher and a matching `wellenrennen/` payload. Debug symbols and development test scripts are excluded. The executable's instruction section is checked unchanged after stripping. Bundled license texts are flat; the optional frontend is excluded from this build.

## Script Conventions
Based on the standard native-port helper structure and checked against current PortMaster-GUI helpers. Keeps `control.txt`, `get_controls`, `$ESUDO`, `pm_platform_helper` and `pm_finish`. Native SDL input is retained. H700's temporary GPU floor is limited to CFW-advertised frequencies and restored on exit; no system/graphics libraries are bundled.
