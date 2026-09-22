#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOST="${RG40XX_HOST:-192.168.178.76}"
USER="${RG40XX_USER:-root}"
REMOTE="/userdata/roms/ports/wellenrennen"

mkdir -p "$ROOT/device-logs"

for name in log.txt portmaster.log wr64.log smoke.log; do
  scp "${USER}@${HOST}:$REMOTE/$name"       "$ROOT/device-logs/$name" 2>/dev/null || true
done

ls -la "$ROOT/device-logs"
