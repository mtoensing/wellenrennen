#!/usr/bin/env bash
# Launch the deployed port through its real PortMaster launcher on the
# RG40XX H, grab framebuffer screenshots while it runs, then stop it.
#
#   SMOKE_SECONDS=90 bash scripts/smoke-rg40xx.sh
#
# The device's SDL2 has no offscreen driver, so the run owns the real display:
# EmulationStation is paused for the duration and always resumed.
# Output: device-logs/smoke.log, device-logs/log.txt, device-logs/fb-*.png
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOST="${RG40XX_HOST:-192.168.178.76}"
USER="${RG40XX_USER:-root}"
SECONDS_TO_RUN="${SMOKE_SECONDS:-90}"
SHOTS="${SMOKE_SHOTS:-30 60 85}"

mkdir -p "$ROOT/device-logs"
rm -f "$ROOT"/device-logs/fb-*.png "$ROOT"/device-logs/fb-*.raw

ssh "${USER}@${HOST}" "SECONDS_TO_RUN=$SECONDS_TO_RUN SHOTS='$SHOTS' bash -s" <<'REMOTE' | tee "$ROOT/device-logs/smoke.log"
set -u
GAMEDIR="/userdata/roms/ports/wellenrennen"
export HOME=/userdata/system
export XDG_DATA_HOME=/userdata/system/.local/share

echo "=== target ==="
uname -a
file "$GAMEDIR/WaveRace64Recomp.aarch64" 2>/dev/null || echo "BLOCKER: binary not deployed"
ls "$GAMEDIR"/*.z64 2>/dev/null || echo "BLOCKER: no ROM in $GAMEDIR"

ES_PID="$(pgrep -f 'exit-on-reboot-required' | head -1)"
resume_es() { [ -n "$ES_PID" ] && kill -CONT "$ES_PID" 2>/dev/null || true; }
trap resume_es EXIT
[ -n "$ES_PID" ] && kill -STOP "$ES_PID" 2>/dev/null || true

rm -f /tmp/wr64-fb-*.raw
for t in $SHOTS; do
  ( sleep "$t"; dd if=/dev/fb0 of=/tmp/wr64-fb-$t.raw bs=2560 count=480 2>/dev/null ) &
done
( sleep 20; top -b -n 1 | head -15 > /tmp/wr64-top.txt ) &

# Memory watchdog. The device has 1 GB, no swap; an earlier run left it
# unreachable. Log to the SD card (survives a hang) and stop the game before
# memory runs out.
MEMLOG="$GAMEDIR/memtrace.txt"
: > "$MEMLOG"
(
  while true; do
    avail=$(awk '/MemAvailable/ {print int($2/1024)}' /proc/meminfo)
    rss=$(ps -o rss= -C WaveRace64Recomp.aarch64 2>/dev/null | awk '{s+=$1} END {print int(s/1024)}')
    load=$(cut -d' ' -f1 /proc/loadavg)
    echo "$(date +%T) avail=${avail}MB game_rss=${rss:-0}MB load=$load" >> "$MEMLOG"
    sync
    if [ "${avail:-999}" -lt 60 ]; then
      echo "$(date +%T) WATCHDOG: MemAvailable ${avail}MB < 60MB, killing game" >> "$MEMLOG"
      pkill -9 -f WaveRace64Recomp.aarch64
      sync
    fi
    sleep 5
  done
) &
WATCHDOG=$!

start=$(date +%s)
timeout -k 15 -s INT "$SECONDS_TO_RUN" bash /userdata/roms/ports/Wellenrennen.sh >/dev/null 2>&1
rc=$?
end=$(date +%s)
# The launcher may be killed before its own cleanup; do it here.
pkill -9 -f WaveRace64Recomp 2>/dev/null
/tmp/weston/westonwrap.sh cleanup >/dev/null 2>&1
pkill -9 gptokeyb 2>/dev/null
kill "$WATCHDOG" 2>/dev/null
echo "=== launcher exit: $rc after $((end - start)) s (124 = still running at timeout) ==="
echo "=== memory trace ==="
cat "$MEMLOG"
echo "=== top at 20 s ==="
cat /tmp/wr64-top.txt 2>/dev/null
REMOTE

scp -q "${USER}@${HOST}:/userdata/roms/ports/wellenrennen/log.txt" "$ROOT/device-logs/log.txt" 2>/dev/null || true
for t in $SHOTS; do
  scp -q "${USER}@${HOST}:/tmp/wr64-fb-$t.raw" "$ROOT/device-logs/fb-$t.raw" 2>/dev/null || continue
  python3 - "$ROOT/device-logs/fb-$t.raw" "$ROOT/device-logs/fb-$t.png" <<'PY'
import struct, sys, zlib
raw = open(sys.argv[1], "rb").read()
w, h = 640, 480
rows = b"".join(
    b"\x00" + bytes(c for i in range(w) for c in (raw[(y*w+i)*4+2], raw[(y*w+i)*4+1], raw[(y*w+i)*4]))
    for y in range(h))
def chunk(t, b):
    return struct.pack(">I", len(b)) + t + b + struct.pack(">I", zlib.crc32(t + b) & 0xffffffff)
open(sys.argv[2], "wb").write(b"\x89PNG\r\n\x1a\n"
    + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
    + chunk(b"IDAT", zlib.compress(rows)) + chunk(b"IEND", b""))
PY
  rm -f "$ROOT/device-logs/fb-$t.raw"
done
ls -la "$ROOT/device-logs"
