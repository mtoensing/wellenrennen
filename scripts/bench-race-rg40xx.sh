#!/usr/bin/env bash
# Short race benchmark on the RG40XX H: run the port with the race input
# script and report the game's frame rate during the race (t = 45..70 s).
#
#   bash scripts/bench-race-rg40xx.sh ["Key = Value" ...]
#
# Optional arguments temporarily override gliden64.ini entries on the device
# for this run only.
set -euo pipefail
HOST="${RG40XX_HOST:-192.168.178.76}"
USER="${RG40XX_USER:-root}"

OVERRIDES="$(printf '%s;' "$@")"
ssh "${USER}@${HOST}" "BENCH_SCRIPT=${BENCH_SCRIPT:-race} OVERRIDES='$OVERRIDES' bash -s" <<'REMOTE'
GAMEDIR=/userdata/roms/ports/wellenrennen
cd "$GAMEDIR"
cp gliden64.ini /tmp/gliden64.ini.bench
IFS=';' read -ra KVS <<< "$OVERRIDES"
for kv in "${KVS[@]}"; do
  [ -z "$kv" ] && continue
  key="${kv%% =*}"
  if grep -q "^$key =" gliden64.ini; then sed -i "s|^$key =.*|$kv|" gliden64.ini; else echo "$kv" >> gliden64.ini; fi
  echo "override: $kv"
done
export HOME=/userdata/system XDG_DATA_HOME=/userdata/system/.local/share
ES_PID="$(pgrep -f exit-on-reboot-required | head -1)"; kill -STOP $ES_PID
while IFS= read -r kv; do case "$kv" in XDG_*|DBUS_*|SDL_*|HOME=*) export "$kv";; esac; done < <(tr '\0' '\n' < /proc/$ES_PID/environ)
export WR64_INPUT_SCRIPT=$GAMEDIR/tests/${BENCH_SCRIPT:-race}.txt
timeout -k 5 -s INT 72 bash /userdata/roms/ports/Wellenrennen.sh >/dev/null 2>&1
for p in /proc/[0-9]*; do [ "$(readlink $p/exe 2>/dev/null)" = $GAMEDIR/WaveRace64Recomp.aarch64 ] && kill -9 $(basename $p); done
kill -CONT $ES_PID
cp /tmp/gliden64.ini.bench gliden64.ini
awk '/state: TIME_TRIAL|state: CHAMPIONSHIP|state: .*RACE/ {print}' log.txt | head -3
# frames/s lines are 5 s windows; the race runs from ~t=42 s.
grep -a "frames/s" log.txt | sed -n '9,13p'
REMOTE
