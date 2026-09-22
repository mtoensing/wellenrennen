#!/usr/bin/env bash
set -euo pipefail
HOST="${RG40XX_HOST:-192.168.178.76}"
USER="${RG40XX_USER:-root}"

echo "KNULLI default password is: linux"
echo "If it fails, read: System Settings -> Security -> Root password"
echo "SSH must be enabled: System Settings -> Services -> SSH"

KEY="${HOME}/.ssh/id_ed25519"
if [ ! -f "$KEY" ]; then
  ssh-keygen -t ed25519 -f "$KEY" -N ""
fi

ssh-copy-id "${USER}@${HOST}"
ssh "${USER}@${HOST}" 'uname -a; echo "---"; cat /etc/os-release 2>/dev/null || true'
