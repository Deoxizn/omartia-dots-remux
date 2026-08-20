#!/usr/bin/env bash
# theme-sync.sh — Manually sync omarchy theme → Caelestia scheme
# Run this after install or if colors look stale.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK="$SCRIPT_DIR/../hooks/theme-set.d/caelestia-sync.sh"

if [[ ! -f "$HOOK" ]]; then
  echo "Error: caelestia-sync.sh not found at $HOOK" >&2
  exit 1
fi

exec bash "$HOOK"
