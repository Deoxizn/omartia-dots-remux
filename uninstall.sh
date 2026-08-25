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

info()  { echo -e "${CYAN}[stellarchy]${NC} $*"; }
ok()    { echo -e "${GREEN}[stellarchy]${NC} $*"; }
warn()  { echo -e "${YELLOW}[stellarchy]${NC} $*"; }
err()   { echo -e "${RED}[stellarchy]${NC} $*" >&2; }

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

# Remove remux lock script from the old install layout (pre-~/.local/bin)
if [[ -f "$HOME/.config/hypr/scripts/caelestia-system-lock" ]]; then
  cmp -s "$HOME/.config/hypr/scripts/caelestia-system-lock" "$HOME/.local/bin/caelestia-system-lock" \
    || cp "$HOME/.local/bin/caelestia-system-lock" "$HOME/.config/hypr/scripts/caelestia-system-lock"
  rm "$HOME/.config/hypr/scripts/caelestia-system-lock"
  rm -rf "$HOME/.config/hypr/scripts"
  ok "  Removed hypr/scripts/caelestia-system-lock (old layout)"
fi

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

# Remove update guard (guard self-neutralizes once Caelestia is gone)
if [[ -f /usr/local/bin/stellarchy-guard-restart-shell.sh ]]; then
  sudo rm -f /usr/local/bin/stellarchy-guard-restart-shell.sh /usr/share/libalpm/hooks/stellarchy-restart-shell-guard.hook
  ok "  Removed update guard"
fi

# Remove splash guard
if [[ -f /usr/local/bin/stellarchy-plymouth-refresh.sh ]]; then
  sudo rm -f /usr/local/bin/stellarchy-plymouth-refresh.sh /usr/share/libalpm/hooks/95-stellarchy-plymouth-refresh.hook
  ok "  Removed splash guard"
fi

# Remove stellarchy menu suite scripts
shopt -s nullglob
menu_scripts=("$HOME/.local/bin/"stellarchy-*)
if (( ${#menu_scripts[@]} )); then
  rm -f "${menu_scripts[@]}"
  ok "  Removed stellarchy menu scripts (${#menu_scripts[@]})"
fi

# Remove legacy pre-rename omartia-* scripts (older installs)
legacy_scripts=("$HOME/.local/bin/"omartia-*)
if (( ${#legacy_scripts[@]} )); then
  rm -f "${legacy_scripts[@]}"
  ok "  Removed legacy omartia-* scripts (${#legacy_scripts[@]})"
fi
shopt -u nullglob

# Remove Caelestia systemd service
if [[ -f "$HOME/.config/systemd/user/caelestia-shell.service" ]]; then
  rm "$HOME/.config/systemd/user/caelestia-shell.service"
  systemctl --user daemon-reload
  ok "  Removed caelestia-shell.service"
fi

# Hand idle/sleep locking back to stock Omarchy's monitor (install.sh disabled it)
# Unmask first — some users mask the unit by hand; enable fails silently on masked units.
systemctl --user unmask omarchy-sleep-lock.service 2>/dev/null
if ! systemctl --user is-enabled --quiet omarchy-sleep-lock.service 2>/dev/null; then
  if systemctl --user enable omarchy-sleep-lock.service 2>/dev/null; then
    ok "  Re-enabled omarchy-sleep-lock.service"
  else
    info "  omarchy-sleep-lock.service not present — skipped"
  fi
fi

# Remove scheme.json (Caelestia runtime state)
if [[ -f "$HOME/.local/state/caelestia/scheme.json" ]]; then
  rm "$HOME/.local/state/caelestia/scheme.json"
  ok "  Removed Caelestia scheme state"
fi

# Restore the stock splash if stellarchy is active — leaving it set after
# the theme dir stops being maintained risks an unbootable-looking boot.
if grep -q '^Theme=stellarchy' /etc/plymouth/plymouthd.conf 2>/dev/null; then
  info "Restoring stock Omarchy splash..."
  sudo plymouth-set-default-theme omarchy
  if mountpoint -q /boot && command -v limine-mkinitcpio &>/dev/null; then
    if sudo limine-mkinitcpio; then
      ok "  Stock splash restored, initramfs rebuilt"
    else
      warn "  limine-mkinitcpio failed — run it manually before rebooting"
    fi
  else
    warn "  /boot not mounted or limine-mkinitcpio missing — run: sudo limine-mkinitcpio"
  fi
fi

# SDDM greeter — remove the stellarchy theme and restore the stock selection,
# so the login screen never points at a theme dir that no longer exists.
if [[ -d /usr/share/sddm/themes/stellarchy ]]; then
  info "Removing stellarchy SDDM theme..."
  sudo rm -rf /usr/share/sddm/themes/stellarchy
  if [[ -f /etc/sddm.conf.d/10-theme.conf ]] && grep -q '^Current=stellarchy' /etc/sddm.conf.d/10-theme.conf; then
    sudo sed -i 's/^Current=.*/Current=omarchy/' /etc/sddm.conf.d/10-theme.conf
    ok "  Theme removed, greeter back to omarchy"
  else
    ok "  Theme removed"
  fi
fi

# Remove state file (repo path)
if [[ -f "$HOME/.local/state/stellarchy/repo-dir" ]]; then
  rm "$HOME/.local/state/stellarchy/repo-dir"
  ok "  Removed stellarchy state file"
fi
rmdir "$HOME/.local/state/stellarchy" 2>/dev/null || true

# Remove repo directory if it exists at the default XDG location
if [[ -d "$HOME/.local/opt/stellarchy" ]]; then
  echo ""
  read -rp "Remove repo at ~/.local/opt/stellarchy? [y/N] " REMOVE_REPO
  if [[ "$REMOVE_REPO" =~ ^[Yy]$ ]]; then
    rm -rf "$HOME/.local/opt/stellarchy"
    ok "  Removed ~/.local/opt/stellarchy"
  else
    info "  Repo preserved at ~/.local/opt/stellarchy"
  fi
fi

# Clean up stray ~/sddm-stellarchy directory (leftover from old installs)
if [[ -d "$HOME/sddm-stellarchy" ]]; then
  info "Removing stray ~/sddm-stellarchy directory..."
  rm -rf "$HOME/sddm-stellarchy"
  ok "  Removed ~/sddm-stellarchy"
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
