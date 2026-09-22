#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/versions.sh"

ROM="${1:-${WR64_ROM:-}}"

if [ -z "$ROM" ]; then
  echo "Usage: $0 /path/to/Wave-Race-64-USA-Rev-A.z64" >&2
  echo "or set WR64_ROM." >&2
  exit 2
fi

if [ ! -f "$ROM" ]; then
  echo "ROM not found: $ROM" >&2
  exit 2
fi

command -v sha1sum >/dev/null 2>&1 || {
  echo "sha1sum is required" >&2
  exit 2
}

ACTUAL="$(sha1sum "$ROM" | awk '{print $1}')"
SIZE="$(wc -c < "$ROM" | tr -d ' ')"

echo "ROM: $ROM"
echo "Size: $SIZE bytes"
echo "SHA-1: $ACTUAL"

if [ "$ACTUAL" != "$WR64_ROM_SHA1" ]; then
  echo "FAIL: unsupported ROM." >&2
  echo "Expected USA Rev A SHA-1: $WR64_ROM_SHA1" >&2
  exit 1
fi

if [ "$SIZE" != "8388608" ]; then
  echo "FAIL: SHA matched unexpectedly but size is not 8 MiB." >&2
  exit 1
fi

echo "PASS: supported Wave Race 64 USA Rev A ROM."
