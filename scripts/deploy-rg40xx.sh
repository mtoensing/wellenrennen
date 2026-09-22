#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOST="${RG40XX_HOST:-192.168.178.76}"
USER="${RG40XX_USER:-root}"
REMOTE="/userdata/roms/ports"
ZIP="$ROOT/dist/wellenrennen.zip"

test -f "$ZIP" || {
  echo "Missing $ZIP"
  echo "A complete ARM64 game build has not been packaged yet."
  exit 1
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
unzip -q "$ZIP" -d "$TMP"

ssh "${USER}@${HOST}" "mkdir -p '$REMOTE/wellenrennen'"

# Never use --delete here: the device directory may contain the user's ROM,
# saves, settings and logs that are intentionally not part of the package.
rsync -rlptD -v \
  --exclude='*.z64' --exclude='*.n64' --exclude='*.v64' \
  "$TMP/wellenrennen/" "${USER}@${HOST}:$REMOTE/wellenrennen/"

scp "$TMP/Wellenrennen.sh" "${USER}@${HOST}:$REMOTE/Wellenrennen.sh"

echo "Deployed to $HOST:$REMOTE"
