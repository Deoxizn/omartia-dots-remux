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

# Stop and disable Caelestia Shell systemd service
if systemctl --user is-active caelestia-shell.service &>/dev/null; then
  info "Stopping Caelestia Shell service..."
  systemctl --user stop caelestia-shell.service
  systemctl --user disable caelestia-shell.service
  ok "Caelestia Shell service stopped and disabled"
fi

# Kill any lingering Caelestia Shell process
if pgrep -f "qs.*caelestia\|quickshell.*caelestia" &>/dev/null; then
  info "Killing lingering Caelestia Shell process..."
  pkill -f "qs.*caelestia\|quickshell.*caelestia" 2>/dev/null || true
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

# Remove Caelestia autostart override from hyprland.lua if backup didn't have it
HYPRLAND_FILE="$HOME/.config/hypr/hyprland.lua"
if [[ -f "$HYPRLAND_FILE" ]] && ! grep -q 'require("default.hypr.autostart")' "$LATEST_BACKUP/hyprland.lua" 2>/dev/null; then
  sed -i '/^-- Caelestia: prevent default omarchy autostart/d' "$HYPRLAND_FILE"
  sed -i '/^package.loaded\["default.hypr.autostart"\]/d' "$HYPRLAND_FILE"
  sed -i '/^$/N;/^\n$/d' "$HYPRLAND_FILE"  # Remove resulting blank lines
  ok "  Removed Caelestia autostart override from hyprland.lua"
fi

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

# Remove Caelestia systemd service
if [[ -f "$HOME/.config/systemd/user/caelestia-shell.service" ]]; then
  rm "$HOME/.config/systemd/user/caelestia-shell.service"
  systemctl --user daemon-reload
  ok "  Removed caelestia-shell.service"
fi

# Remove scheme.json (Caelestia runtime state)
if [[ -f "$HOME/.local/state/caelestia/scheme.json" ]]; then
  rm "$HOME/.local/state/caelestia/scheme.json"
  ok "  Removed Caelestia scheme state"
fi

# Reinstall omarchy-dev if it was removed during install
OMARCHY_DEV_FLAG="$HOME/.local/state/omartia-dots-remux/omarchy-dev-removed"
if [[ -f "$OMARCHY_DEV_FLAG" ]]; then
  if ! pacman -Qi omarchy-dev &>/dev/null; then
    echo ""
    warn "omarchy-dev was removed during install (dependency conflict with quickshell-git)"
    read -rp "Reinstall omarchy-dev? [y/N] " REINSTALL
    if [[ "$REINSTALL" =~ ^[Yy]$ ]]; then
      info "Reinstalling omarchy-dev..."
      sudo pacman -S --noconfirm omarchy-dev
      ok "omarchy-dev reinstalled"
    else
      warn "Skipped — you can reinstall later: sudo pacman -S omarchy-dev"
    fi
  fi
  rm -f "$OMARCHY_DEV_FLAG"
  # Clean up state dir if empty
  rmdir "$HOME/.local/state/omartia-dots-remux" 2>/dev/null || true
fi

echo ""
ok "═══════════════════════════════════════════"
ok "  omartia-dots-remux uninstalled!"
ok "═══════════════════════════════════════════"
echo ""
info "Log out and back in to restore omarchy-shell."
info "Backup preserved at: $LATEST_BACKUP"
info "To remove backup: rm -rf $BACKUP_DIR"
