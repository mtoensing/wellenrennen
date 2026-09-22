#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOST="${RG40XX_HOST:-192.168.178.76}"
USER="${RG40XX_USER:-root}"
OUT="$ROOT/device-logs/probe-rg40xx.txt"

mkdir -p "$ROOT/device-logs"

ssh "${USER}@${HOST}" 'bash -s' <<'REMOTE' | tee "$OUT"
set +e

echo "=== identity ==="
date 2>/dev/null || true
uname -a
uname -m
cat /etc/os-release 2>/dev/null || true

echo "=== memory ==="
free -h 2>/dev/null || cat /proc/meminfo | head -20

echo "=== graphics devices ==="
ls -la /dev/dri 2>/dev/null || true
ls -la /dev/mali* 2>/dev/null || true

echo "=== loaded GPU modules ==="
lsmod 2>/dev/null | grep -Ei 'mali|panfrost|drm' || true

echo "=== SDL2 ==="
ldconfig -p 2>/dev/null | grep -i SDL2 || true
find /usr/lib /lib -maxdepth 4 -iname 'libSDL2*.so*' 2>/dev/null | head -40 || true

echo "=== Vulkan loader ==="
ldconfig -p 2>/dev/null | grep -i vulkan || true
find /usr/lib /lib -maxdepth 4 -iname 'libvulkan*.so*' 2>/dev/null | head -40 || true

echo "=== Mali Vulkan exports ==="
if [ -f /usr/lib/libmali.so ]; then
  file /usr/lib/libmali.so 2>/dev/null || true
  ldd /usr/lib/libmali.so 2>/dev/null || true
  if command -v readelf >/dev/null 2>&1; then
    readelf -Ws /usr/lib/libmali.so 2>/dev/null | grep -E 'vkGetInstanceProcAddr|vkCreateInstance|vkEnumerateInstance' | head -30 || true
  elif command -v nm >/dev/null 2>&1; then
    nm -D /usr/lib/libmali.so 2>/dev/null | grep -E 'vkGetInstanceProcAddr|vkCreateInstance|vkEnumerateInstance' | head -30 || true
  else
    echo "readelf/nm unavailable; using binary string fallback"
    for sym in vkGetInstanceProcAddr vkCreateInstance vkEnumerateInstanceExtensionProperties; do
      if grep -a -q "$sym" /usr/lib/libmali.so 2>/dev/null; then
        echo "FOUND STRING: $sym"
      else
        echo "NO STRING: $sym"
      fi
    done
  fi

  echo "=== direct loader smoke ==="
  if command -v python3 >/dev/null 2>&1; then
    python3 - <<'PY'
import ctypes
p="/usr/lib/libmali.so"
try:
    lib=ctypes.CDLL(p)
    print("dlopen PASS:", p)
    for s in ("vkGetInstanceProcAddr","vkCreateInstance","vkEnumerateInstanceExtensionProperties"):
        try:
            getattr(lib,s)
            print("dlsym PASS:", s)
        except AttributeError:
            print("dlsym FAIL:", s)
except OSError as e:
    print("dlopen FAIL:", e)
PY
  else
    echo "python3 unavailable; skipping true dlopen/dlsym smoke"
  fi
else
  echo "/usr/lib/libmali.so not found"
fi

echo "=== Vulkan ICDs ==="
for d in /etc/vulkan/icd.d /usr/share/vulkan/icd.d /usr/local/share/vulkan/icd.d; do
  if [ -d "$d" ]; then
    echo "-- $d"
    for f in "$d"/*.json; do
      [ -f "$f" ] || continue
      echo "FILE: $f"
      cat "$f"
      echo
    done
  fi
done

echo "=== Vulkan tools ==="
if command -v vulkaninfo >/dev/null 2>&1; then
  vulkaninfo --summary 2>&1 || true
else
  echo "vulkaninfo not installed; this is not itself a failure"
fi

echo "=== PortMaster ==="
for p in   /opt/system/Tools/PortMaster/control.txt   /opt/tools/PortMaster/control.txt   /userdata/system/.local/share/PortMaster/control.txt   /roms/ports/PortMaster/control.txt; do
  [ -f "$p" ] && echo "control.txt: $p"
done

echo "=== existing Wellenrennen files ==="
ls -la /userdata/roms/ports/wellenrennen 2>/dev/null || true

echo "=== ROM candidates ==="
find /userdata/roms/ports/wellenrennen -maxdepth 1   \( -iname '*.z64' -o -iname '*.n64' -o -iname '*.v64' \)   -type f -print 2>/dev/null || true
REMOTE

echo
echo "Saved: $OUT"
