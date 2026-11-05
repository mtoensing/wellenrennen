#!/usr/bin/env bash
# Synchronous render diagnostic. PROBE_MODE=commands replays owned GL data.
# Default PROBE_MODE=hle repeats the N64 translation. No interpolation.
# The batch finishes on the GPU before the game's DP-complete is sent.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOST="${RG40XX_HOST:-192.168.178.76}"
mkdir -p "$ROOT/device-logs"
STAMP="$(date +%Y%m%d-%H%M%S)"
MODE="${PROBE_MODE:-hle}"
case "$MODE" in hle|commands) ;; *) echo "PROBE_MODE must be hle or commands" >&2; exit 2;; esac
ssh -o BatchMode=yes "root@$HOST" "PROBE_MODE=$MODE bash -s" <<'REMOTE' | tee "$ROOT/device-logs/render-probe-$STAMP.log"
set -u
GAMEDIR=/userdata/roms/ports/wellenrennen
ES_PID="$(pgrep -f exit-on-reboot-required | head -1)"
[ -n "$ES_PID" ] || { echo 'EmulationStation not found'; exit 1; }
while IFS= read -r kv; do
  case "$kv" in XDG_*|DBUS_*|SDL_*|HOME=*) export "$kv";; esac
done < <(tr '\0' '\n' < "/proc/$ES_PID/environ")
cleanup() {
  pkill -TERM -f '^/userdata/roms/ports/wellenrennen/WaveRace64Recomp' 2>/dev/null || true
  kill -CONT "$ES_PID" 2>/dev/null || true
}
trap cleanup EXIT HUP INT TERM
kill -STOP "$ES_PID"
unset WR64_RENDER_PROBE WR64_COMMAND_PROBE
if [ "$PROBE_MODE" = commands ]; then export WR64_COMMAND_PROBE=1; else export WR64_RENDER_PROBE=1; fi
export WR64_INPUT_SCRIPT="$GAMEDIR/tests/race.txt"
unset WR64_INTERP
uname -a
sha256sum "$GAMEDIR/WaveRace64Recomp.aarch64" "$GAMEDIR/gliden64/mupen64plus-video-GLideN64.so"
timeout -k 10 -s TERM 80 bash /userdata/roms/ports/Wellenrennen.sh >/dev/null 2>&1
rc=$?
echo "launcher termination=$rc (124: deliberately stopped at 80 s)"
grep -aE 'command-probe|render-probe|frames/s|state:|audio device|renderer ready|UNKNOWN GBI|invalid size' "$GAMEDIR/log.txt"
REMOTE
scp -q "root@$HOST:/userdata/roms/ports/wellenrennen/log.txt" "$ROOT/device-logs/render-probe-$STAMP-game.log"
