#!/usr/bin/env bash
# Real-launcher race run with the optional GPU frame synthesizer.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOST="${RG40XX_HOST:-192.168.178.76}"
STAMP="$(date +%Y%m%d-%H%M%S)"
GPU_TEST="${SYNTH_GPU_MAX:-0}"
PROFILE="${SYNTH_PROFILE:-0}"
SEQUENCE="${SYNTH_SEQUENCE:-0}"
SHOTS="${SYNTH_SHOTS:-0}"
case "$SHOTS" in 0|1) ;; *) exit 2;; esac
DUMP="${SYNTH_DUMP:-0}"
DUMP_AT="${SYNTH_DUMP_AT:-55}"
DURATION="${SYNTH_SECONDS:-85}"
case "$DUMP_AT:$DURATION" in *[!0-9:]*|:*) exit 2;; esac
case "$DUMP" in 0|1) ;; *) exit 2;; esac
case "$PROFILE:$SEQUENCE" in [01]:[01]) ;; *) exit 2;; esac
case "$GPU_TEST" in 0|1) ;; *) exit 2;; esac
mkdir -p "$ROOT/device-logs"
ssh -o BatchMode=yes "root@$HOST" "GPU_TEST=$GPU_TEST PROFILE=$PROFILE SEQUENCE=$SEQUENCE DUMP=$DUMP DUMP_AT=$DUMP_AT DURATION=$DURATION SHOTS=$SHOTS bash -s" <<'REMOTE' | tee "$ROOT/device-logs/synth-$STAMP.log"
set -u
GAMEDIR=/userdata/roms/ports/wellenrennen
ES_PID="$(pgrep -f exit-on-reboot-required | head -1)"
[ -n "$ES_PID" ] || exit 2
while IFS= read -r kv; do
  case "$kv" in XDG_*|DBUS_*|SDL_*|HOME=*) export "$kv";; esac
done < <(tr '\0' '\n' < "/proc/$ES_PID/environ")
GPU_MIN="$(cat /sys/class/devfreq/gpu/min_freq)"
cleanup() {
  printf '%s\n' "$GPU_MIN" > /sys/class/devfreq/gpu/min_freq
  pkill -TERM -f '^/userdata/roms/ports/wellenrennen/WaveRace64Recomp' 2>/dev/null || true
  for child in $(jobs -pr); do kill "$child" 2>/dev/null || true; done
  kill -CONT "$ES_PID" 2>/dev/null || true
}
trap cleanup EXIT HUP INT TERM
kill -STOP "$ES_PID"
if [ "$GPU_TEST" = 1 ]; then
  GPU_MAX="$(tr ' ' '\n' < /sys/class/devfreq/gpu/available_frequencies | sort -n | tail -1)"
  printf '%s\n' "$GPU_MAX" > /sys/class/devfreq/gpu/min_freq
  echo "temporary GPU minimum $GPU_MAX; restore $GPU_MIN on exit"
fi
export WR64_FRAME_SYNTH=1 WR64_INPUT_SCRIPT="$GAMEDIR/tests/race.txt"
unset WR64_INTERP WR64_RENDER_PROBE WR64_COMMAND_PROBE WR64_SYNTH_PROFILE
[ "$PROFILE" = 1 ] && export WR64_SYNTH_PROFILE=1
unset WR64_SYNTH_DUMP
[ "$DUMP" = 1 ] && export WR64_SYNTH_DUMP="$DUMP_AT"
if [ "$SEQUENCE" = 1 ]; then
 ( sleep 55; FB_SAMPLE_VSYNC=1 /tmp/wr64-fb-sample 5 /tmp/wr64-sequence > /tmp/wr64-sequence-cadence.txt ) &
fi
if [ "$SHOTS" = 1 ]; then
 [ "$DURATION" -gt 55 ] && ( sleep 55; dd if=/dev/fb0 of=/tmp/wr64-synth-55.raw bs=2560 count=480 2>/dev/null ) &
 [ "$DURATION" -gt 65 ] && ( sleep 65; dd if=/dev/fb0 of=/tmp/wr64-synth-65.raw bs=2560 count=480 2>/dev/null ) &
fi
# Signal the game only: killing the whole launcher group also kills tee,
# turning the game's shutdown/cache logging into SIGPIPE.
bash /userdata/roms/ports/Wellenrennen.sh >/dev/null 2>&1 &
LAUNCHER=$!
(
 sleep "$DURATION"
 pkill -TERM -f '^/userdata/roms/ports/wellenrennen/WaveRace64Recomp' 2>/dev/null || true
 sleep 10
 pkill -KILL -f '^/userdata/roms/ports/wellenrennen/WaveRace64Recomp' 2>/dev/null || true
) >/dev/null 2>&1 &
STOPPER=$!
wait "$LAUNCHER"
rc=$?
kill "$STOPPER" 2>/dev/null || true
echo "launcher exit=$rc; game-only TERM scheduled at $DURATION s (KILL fallback after 10 s)"
grep -aE 'frame-synth|frames/s|state:|audio device|renderer ready|error|Error|UNKNOWN GBI' "$GAMEDIR/log.txt"
REMOTE
scp -q "root@$HOST:/userdata/roms/ports/wellenrennen/log.txt" "$ROOT/device-logs/synth-$STAMP-game.log"
for t in 55 65; do [ "$SHOTS" = 1 ] && [ "$DURATION" -gt "$t" ] || continue; scp -q "root@$HOST:/tmp/wr64-synth-$t.raw" "$ROOT/device-logs/synth-$STAMP-$t.raw" || true; done

if [ "$SEQUENCE" = 1 ]; then
 scp -q "root@$HOST:/tmp/wr64-sequence-cadence.txt" "$ROOT/device-logs/synth-$STAMP-cadence.txt"
 mkdir -p "$ROOT/device-logs/synth-$STAMP-sequence"
 scp -q "root@$HOST:/tmp/wr64-sequence-*.raw" "$ROOT/device-logs/synth-$STAMP-sequence/"
fi

if [ "$DUMP" = 1 ]; then
 mkdir -p "$ROOT/device-logs/synth-$STAMP-dump"
 scp -q "root@$HOST:/tmp/wr64-*.rgba" "$ROOT/device-logs/synth-$STAMP-dump/"
fi
