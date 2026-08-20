#!/usr/bin/env bash
# omartia-dots-remux uninstaller
# Restores configs from backup, removes Caelestia Shell configs

set -euo pipefail

BACKUP_DIR="$HOME/.config/omartia-dots-remux-backup"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${CYAN}[omartia]${NC} $*"; }
ok()    { echo -e "${GREEN}[omartia]${NC} $*"; }
warn()  { echo -e "${YELLOW}[omartia]${NC} $*"; }
err()   { echo -e "${RED}[omartia]${NC} $*" >&2; }

# Find latest backup
if [[ ! -d "$BACKUP_DIR" ]]; then
  err "No backup found at $BACKUP_DIR"
  err "Was omartia-dots-remux ever installed?"
  exit 1
fi

LATEST_BACKUP=$(ls -dt "$BACKUP_DIR"/*/ 2>/dev/null | head -1)
if [[ -z "$LATEST_BACKUP" ]]; then
  err "No backup directories found"
  exit 1
fi

info "Using backup: $LATEST_BACKUP"
echo ""

read -rp "Restore configs from backup and remove Caelestia Shell? [y/N] " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
  info "Aborted"
  exit 0
fi

# Kill Caelestia Shell if running
if pgrep -f "caelestia shell" &>/dev/null; then
  info "Stopping Caelestia Shell..."
  pkill -f "caelestia shell" 2>/dev/null || true
  sleep 1
  ok "Caelestia Shell stopped"
fi

# Restore hypr configs from backup
info "Restoring Hyprland configs..."
for f in "$LATEST_BACKUP"/*.lua "$LATEST_BACKUP"/*.conf; do
  [[ -f "$f" ]] || continue
  BASENAME=$(basename "$f")
  cp "$f" "$HOME/.config/hypr/$BASENAME"
  ok "  Restored hypr/$BASENAME"
done

# Restore omarchy shell.json
if [[ -f "$LATEST_BACKUP/shell.json" ]]; then
  cp "$LATEST_BACKUP/shell.json" "$HOME/.config/omarchy/shell.json"
  ok "  Restored omarchy/shell.json"
fi

# Restore caelestia dir if backed up
if [[ -d "$LATEST_BACKUP/caelestia" ]]; then
  rm -rf "$HOME/.config/caelestia"
  cp -r "$LATEST_BACKUP/caelestia" "$HOME/.config/caelestia"
  ok "  Restored caelestia/"
fi

# Remove theme bridge hook
if [[ -f "$HOME/.config/omarchy/hooks/theme-set.d/caelestia-sync.sh" ]]; then
  rm "$HOME/.config/omarchy/hooks/theme-set.d/caelestia-sync.sh"
  ok "  Removed theme bridge hook"
fi

# Remove scheme.json (Caelestia runtime state)
if [[ -f "$HOME/.local/state/caelestia/scheme.json" ]]; then
  rm "$HOME/.local/state/caelestia/scheme.json"
  ok "  Removed Caelestia scheme state"
fi

echo ""
ok "═══════════════════════════════════════════"
ok "  omartia-dots-remux uninstalled!"
ok "═══════════════════════════════════════════"
echo ""
info "Log out and back in to restore omarchy-shell."
info "Backup preserved at: $LATEST_BACKUP"
info "To remove backup: rm -rf $BACKUP_DIR"
