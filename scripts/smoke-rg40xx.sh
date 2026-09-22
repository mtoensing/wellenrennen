#!/usr/bin/env bash
set -euo pipefail

HOST="${RG40XX_HOST:-192.168.178.76}"
USER="${RG40XX_USER:-root}"

ssh "${USER}@${HOST}" bash -s <<'REMOTE'
set -u

GAMEDIR="/userdata/roms/ports/wellenrennen"
BIN="$GAMEDIR/WaveRace64Recomp.aarch64"
LOG="$GAMEDIR/smoke.log"

mkdir -p "$GAMEDIR"
exec > >(tee "$LOG") 2>&1

echo "=== target ==="
uname -a
cat /etc/os-release 2>/dev/null || true

echo "=== binary ==="
file "$BIN" 2>/dev/null || echo "BLOCKER: binary not deployed"

echo "=== dynamic dependencies ==="
ldd "$BIN" 2>&1 || true

echo "=== SDL2 ==="
ldconfig -p 2>/dev/null | grep -i SDL2 || true
find /usr/lib /lib -maxdepth 3 -iname 'libSDL2*.so*' 2>/dev/null | head -20 || true

echo "=== graphics devices ==="
ls -la /dev/dri 2>/dev/null || true
ls -la /dev/mali* 2>/dev/null || true

echo "=== Vulkan ==="
ldconfig -p 2>/dev/null | grep -i vulkan || true
find /usr/share/vulkan /etc/vulkan /usr/lib /lib \
  -maxdepth 4 \( -iname '*vulkan*' -o -iname '*icd*.json' \) \
  2>/dev/null | head -80 || true

if command -v vulkaninfo >/dev/null 2>&1; then
  vulkaninfo --summary 2>&1 || true
fi

echo "=== ROM ==="
ROM=""
for f in "$GAMEDIR"/*.z64; do
  [ -f "$f" ] && ROM="$f" && break
done

if [ -z "$ROM" ]; then
  echo "BLOCKER: copy Wave Race 64 (USA) (Rev A).z64 into $GAMEDIR"
  exit 2
fi

echo "ROM: $ROM"

if [ ! -f "$BIN" ]; then
  exit 3
fi

echo "Vulkan/device probe complete."
echo "Do not launch RT64 here until a complete ARM64 runtime build is deployed."
REMOTE
