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

# Ensure Hyprland can launch Omarchy shell — remove any remux/Noctarchy stub that
# blocks default autostart. This must happen AFTER restore, since the backup itself
# may have been taken after the stub was installed (e.g. machine already had
# Noctarchy's hyprland.lua when stellarchy was installed). Without this, Hyprland
# starts with no shell, no wallpaper, and only the few binds in the user's override.
HYPRLAND_FILE="$HOME/.config/hypr/hyprland.lua"
if [[ -f "$HYPRLAND_FILE" ]] && grep -q 'package\.loaded\["default\.hypr\.autostart"\]' "$HYPRLAND_FILE" 2>/dev/null; then
  sed -i '/^--.*prevent default omarchy autostart/d' "$HYPRLAND_FILE"
  sed -i '/^--.*Must be set AFTER bootstrap/d' "$HYPRLAND_FILE"
  sed -i '/^--.*on every load\/reload.*wiped/d' "$HYPRLAND_FILE"
  sed -i '/^package\.loaded\["default\.hypr\.autostart"\]/d' "$HYPRLAND_FILE"
  sed -i '/^$/N;/^\n$/d' "$HYPRLAND_FILE"  # Remove resulting blank lines
  ok "  Removed autostart block from hyprland.lua (Omarchy autostart restored)"
fi
# If hyprland.lua is still missing the bootstrap (corrupt restore), seed stock template
if [[ ! -f "$HYPRLAND_FILE" ]] || ! grep -q 'dofile.*bootstrap\.lua' "$HYPRLAND_FILE" 2>/dev/null; then
  warn "  hyprland.lua missing bootstrap — seeding from Omarchy template"
  if [[ -f /usr/share/omarchy/config/hypr/hyprland.lua ]]; then
    cp /usr/share/omarchy/config/hypr/hyprland.lua "$HYPRLAND_FILE"
    ok "  Seeded hyprland.lua from Omarchy stock"
  else
    warn "  Omarchy template not found — Hyprland may not start cleanly"
  fi
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

# Remove repo sync hook
if [[ -f "$HOME/.config/omarchy/hooks/post-update.d/stellarchy-repo-sync.sh" ]]; then
  rm "$HOME/.config/omarchy/hooks/post-update.d/stellarchy-repo-sync.sh"
  ok "  Removed repo sync hook"
fi

# Remove update guard (guard self-neutralizes once Caelestia is gone)
# Handles both current (stellarchy) and legacy (omartia) names.
for guard_bin in /usr/local/bin/stellarchy-guard-restart-shell.sh /usr/local/bin/omartia-guard-restart-shell.sh; do
  [[ -f "$guard_bin" ]] || continue
  sudo rm -f "$guard_bin"
  ok "  Removed update guard bin: $(basename "$guard_bin")"
done
for guard_hook in /usr/share/libalpm/hooks/stellarchy-restart-shell-guard.hook /usr/share/libalpm/hooks/omartia-restart-shell-guard.hook; do
  [[ -f "$guard_hook" ]] || continue
  sudo rm -f "$guard_hook"
  ok "  Removed update guard hook: $(basename "$guard_hook")"
done
# Catch any stray guard files matching *stellarchy* or *omartia* in those dirs
shopt -s nullglob
for f in /usr/local/bin/*stellarchy* /usr/local/bin/*omartia* /usr/share/libalpm/hooks/*stellarchy* /usr/share/libalpm/hooks/*omartia*; do
  [[ -e "$f" ]] || continue
  sudo rm -f "$f"
  ok "  Removed stray guard: $f"
done
shopt -u nullglob

# Revert guard patch from omarchy-restart-shell — the guard inserts 5 lines after
# the shebang (comment + if pgrep + echo + exit 0 + fi). The marker is
# "omartia-dots-remux" (historical) or "stellarchy" or "Caelestia handles".
F=/usr/share/omarchy/bin/omarchy-restart-shell
if [[ -f "$F" ]] && grep -qE 'stellarchy|omartia-dots-remux|Caelestia handles' "$F" 2>/dev/null; then
  GUARD_REVERT=$(mktemp /tmp/stellarchy-guard-revert.XXXXXX.py)
  cat > "$GUARD_REVERT" << 'PYEOF'
import sys
p = sys.argv[1]
with open(p) as f:
    lines = f.readlines()
result = []
for i, l in enumerate(lines):
    stripped = l.strip()
    if stripped == "exit 0" and i + 1 < len(lines) and lines[i+1].strip() == "fi":
        # Only drop the guard's exit/fi pair — check surrounding guard markers to avoid nuking unrelated exits
        window = "".join(lines[max(0,i-3):i+3])
        if "Caelestia" in window or "stellarchy" in window or "omartia-dots-remux" in window or "pgrep" in window:
            continue
    if stripped == "fi" and i > 0 and lines[i-1].strip() == "exit 0":
        window = "".join(lines[max(0,i-3):i+3])
        if "Caelestia" in window or "stellarchy" in window or "omartia-dots-remux" in window or "pgrep" in window:
            continue
    if "stellarchy" in l or "omartia-dots-remux" in l or "Caelestia handles the shell" in l or "pgrep -f" in l or "qs -c caelestia" in l or "Caelestia active" in l:
        continue
    result.append(l)
# Clean up double blank lines left by removal (keep single)
with open(p, "w") as f:
    f.writelines(result)
print("guard reverted")
PYEOF
  sudo python3 "$GUARD_REVERT" "$F"
  rm -f "$GUARD_REVERT"
  ok "  Reverted guard patch from omarchy-restart-shell"
fi

# Restore bar toggle (may have been hidden)
rm -f "$HOME/.local/state/omarchy/toggles/bar-off" 2>/dev/null
ok "  Restored bar toggle (bar-off removed)"

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

# ──────────────────────────────────────────────
# Thorough scrub: actively search and remove any remaining Stellarchy /
# Caelestia / omartia artifacts, then warn about any references still found.
# ──────────────────────────────────────────────

info "Scrubbing remaining Caelestia/Stellarchy artifacts..."

# Caelestia Shell checkout (cloned repo). Wasted if left behind.
if [[ -d "$HOME/.config/quickshell/caelestia" ]]; then
  rm -rf "$HOME/.config/quickshell/caelestia"
  ok "  Removed ~/.config/quickshell/caelestia checkout"
  rmdir "$HOME/.config/quickshell" 2>/dev/null || true
fi

# Caelestia live config — remove if install created it. If the user had a
# pre-existing ~/.config/caelestia before install, the earlier restore already
# brought it back, so don't nuke it again.
if [[ -d "$HOME/.config/caelestia" ]] && [[ ! -d "$LATEST_BACKUP/caelestia" ]]; then
  rm -rf "$HOME/.config/caelestia"
  ok "  Removed ~/.config/caelestia"
elif [[ -d "$HOME/.config/caelestia" ]]; then
  info "  Preserved ~/.config/caelestia (restored from backup)"
fi

# Hyprland merge history (sync.sh's 3-way base)
if [[ -d "$HOME/.config/hypr/.stellarchy-base" ]]; then
  rm -rf "$HOME/.config/hypr/.stellarchy-base"
  ok "  Removed hypr/.stellarchy-base"
fi

# Stellarchy identity overlay (~/.config/stellarchy/os-release) — shell patch reads this
if [[ -d "$HOME/.config/stellarchy" ]]; then
  rm -rf "$HOME/.config/stellarchy"
  ok "  Removed ~/.config/stellarchy overlay"
fi

# Cached Caelestia state (scheme, wallpapers, etc.) and disk cache
if [[ -d "$HOME/.local/state/caelestia" ]]; then
  rm -rf "$HOME/.local/state/caelestia"
  ok "  Removed ~/.local/state/caelestia"
fi
if [[ -d "$HOME/.cache/caelestia" ]]; then
  rm -rf "$HOME/.cache/caelestia"
  ok "  Removed ~/.cache/caelestia"
fi
if [[ -d "$HOME/.local/state/stellarchy" ]]; then
  # repo-dir already handled above; now sweep any stray siblings (logs etc.)
  rm -rf "$HOME/.local/state/stellarchy"
  ok "  Removed ~/.local/state/stellarchy"
fi

# mpv — remove only if we installed it (marker avoids nuking a custom config)
if [[ -f "$HOME/.config/mpv/mpv.conf" ]] && grep -q "omartia-dots-remux" "$HOME/.config/mpv/mpv.conf" 2>/dev/null; then
  rm -f "$HOME/.config/mpv/mpv.conf"
  ok "  Removed mpv/mpv.conf (omartia-owned, native-res window)"
  rmdir "$HOME/.config/mpv" 2>/dev/null || true
fi

# Branding — Stellarchy wordmark TUI art. Remove if still Stellarchy so Omarchy
# falls back to its stock logo/icon at /usr/share/omarchy/*.txt. Never delete
# a genuinely customized file.
for f in screensaver.txt about.txt; do
  p="$HOME/.config/omarchy/branding/$f"
  if [[ -f "$p" ]] && { cmp -s "$p" "$REPO_DIR/branding/$f" 2>/dev/null || grep -q 'Stellarchy' "$p" 2>/dev/null; } then
    rm -f "$p"
    ok "  Removed branding/$f (stellarchy wordmark)"
  fi
done
rmdir "$HOME/.config/omarchy/branding" 2>/dev/null || true

# Fastfetch — Stellarchy logo + OS-line. Remove branded artifacts and restore
# stock only when the live config is still Stellarchy-branded.
if [[ -f "$HOME/.config/fastfetch/stellarchy.png" ]]; then
  # Only remove the PNG if the config references it (i.e. it's ours) or it's unreferenced
  if [[ ! -f "$HOME/.config/fastfetch/config.jsonc" ]] || grep -q 'stellarchy' "$HOME/.config/fastfetch/config.jsonc" 2>/dev/null || true; then
    rm -f "$HOME/.config/fastfetch/stellarchy.png"
    ok "  Removed fastfetch/stellarchy.png"
  fi
fi
if [[ -f "$HOME/.config/fastfetch/config.jsonc" ]] && grep -q 'stellarchy-version' "$HOME/.config/fastfetch/config.jsonc" 2>/dev/null; then
  if [[ -f /etc/fastfetch/config.jsonc ]]; then
    cp /etc/fastfetch/config.jsonc "$HOME/.config/fastfetch/config.jsonc"
    ok "  Restored fastfetch/config.jsonc to stock (removed Stellarchy OS line)"
  else
    rm -f "$HOME/.config/fastfetch/config.jsonc"
    ok "  Removed branded fastfetch/config.jsonc (no stock template to restore)"
  fi
fi

# Stellarchy hooks — sweep any stray copies that bypassed the standard paths
# (e.g. manually copied, old post-update hook names).
shopt -s nullglob
for hook in "$HOME/.config/omarchy/hooks/theme-set.d/"*stellarchy* "$HOME/.config/omarchy/hooks/theme-set.d/"*caelestia* \
           "$HOME/.config/omarchy/hooks/post-update.d/"*stellarchy* "$HOME/.config/omarchy/hooks/post-update.d/"*caelestia*; do
  [[ -e "$hook" ]] || continue
  rm -f "$hook"
  ok "  Removed stray hook: ${hook/#$HOME/\~}"
done
shopt -u nullglob

# Plymouth — ensure the stellarchy theme dir itself is gone after reverting
# the default (the sync/guard above already flipped Theme= back to omarchy).
if [[ -d /usr/share/plymouth/themes/stellarchy ]]; then
  sudo rm -rf /usr/share/plymouth/themes/stellarchy
  ok "  Removed plymouth stellarchy theme dir"
fi
# Plymouth config fallback — if Theme= still points at a missing dir, force omarchy
if grep -q '^Theme=stellarchy' /etc/plymouth/plymouthd.conf 2>/dev/null; then
  warn "  plymouthd.conf still Theme=stellarchy — forcing omarchy and rebuilding initrd"
  sudo plymouth-set-default-theme omarchy
  if mountpoint -q /boot && command -v limine-mkinitcpio &>/dev/null; then
    sudo limine-mkinitcpio && ok "  initramfs rebuilt (omarchy splash)" || warn "  limine-mkinitcpio failed — run manually"
  fi
fi

# System-wide search for leftover stellarchy/omartia/caelestia files
# (covers /usr/local/bin, libalpm hooks, plymouth/sddm dirs, and any manual copies).
info "Searching for leftover Stellarchy references..."
leftovers=""
for base in "$HOME/.config" "$HOME/.local/bin" "$HOME/.local/state" "$HOME/.local/share" /usr/local/bin /usr/share/libalpm/hooks /usr/share/plymouth/themes /usr/share/sddm/themes /etc/plymouth /etc/sddm.conf.d; do
  [[ -e "$base" ]] || continue
  # Use find with -maxdepth to avoid crawling everything; still catch the known install sites.
  # Exclude BACKUP_DIR so we don't delete the backup the user may need to keep.
  hits=$(find "$base" -maxdepth 4 \( -name "*stellarchy*" -o -name "*omartia*" \) -not -path "$BACKUP_DIR/*" -print 2>/dev/null || true)
  # Filter out BACKUP_DIR itself if base is exactly the backup
  hits=$(echo "$hits" | grep -v "^$BACKUP_DIR$" || true)
  if [[ -n "$hits" ]]; then
    leftovers+="$hits"$'\n'
  fi
done
# Also grep for Caelestia shell service remnants that may not have stellarchy in name
if [[ -f "$HOME/.config/systemd/user/caelestia-shell.service" ]]; then
  leftovers+="$HOME/.config/systemd/user/caelestia-shell.service"$'\n'
fi
leftovers=$(echo -n "$leftovers" | sed '/^$/d' | sort -u)
if [[ -n "$leftovers" ]]; then
  warn "  Leftover Stellarchy artifacts still present (actively removing):"
  echo "$leftovers" | while IFS= read -r p; do
    [[ -e "$p" ]] || continue
    warn "    $p"
    # Actively remove — these are all inside the install sites enumerated above
    if [[ -d "$p" ]]; then
      rm -rf "$p" 2>/dev/null || sudo rm -rf "$p" 2>/dev/null || true
    else
      rm -f "$p" 2>/dev/null || sudo rm -f "$p" 2>/dev/null || true
    fi
  done
  ok "  Leftover files removed"
else
  ok "  No leftover Stellarchy files found"
fi

# Final content search for the string "stellarchy" inside live hypr / hook / service files
# (warns but does not auto-edit — lets user inspect before nuking references).
hits=$(grep -RIl "stellarchy\|omartia-dots-remux" "$HOME/.config/hypr" "$HOME/.config/omarchy/hooks" "$HOME/.config/systemd/user" 2>/dev/null | head -20 || true)
if [[ -n "$hits" ]]; then
  warn "  Remaining references to 'stellarchy' found in:"
  echo "$hits" | while IFS= read -r f; do warn "    $f"; done
  warn "  Review and remove stellarchy mentions manually if needed"
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

# ──────────────────────────────────────────────
# Restore Omarchy shell — guard is now gone, so restart will actually launch it
# ──────────────────────────────────────────────

info "Restoring Omarchy shell..."
# Ensure any lingering Caelestia quickshell is gone before restart (guard checks pgrep)
if pgrep -f "qs.*caelestia\|quickshell.*caelestia" &>/dev/null; then
  pkill -f "qs.*caelestia\|quickshell.*caelestia" 2>/dev/null || true
  sleep 1
fi
# Reload user systemd daemon (we removed caelestia-shell.service)
systemctl --user daemon-reload 2>/dev/null || true

if command -v omarchy-restart-shell &>/dev/null; then
  info "  Running omarchy-restart-shell..."
  if omarchy-restart-shell 2>&1 | head -30; then
    ok "  Omarchy shell restarted"
  else
    warn "  omarchy-restart-shell reported an error — try: omarchy-restart-shell or log out/in"
  fi
elif command -v hyprctl &>/dev/null && hyprctl dispatch --help &>/dev/null 2>&1; then
  # Fallback: directly dispatch Omarchy's launcher (mirrors what omarchy-restart-shell does)
  if hyprctl dispatch "exec omarchy-launch-shell" >/dev/null 2>&1; then
    sleep 2
    if pgrep -f "quickshell.*omarchy" &>/dev/null || pgrep -x omarchy-shell &>/dev/null; then
      ok "  Omarchy shell launched via hyprctl"
    else
      warn "  Launch dispatched — verify with: pgrep -a quickshell"
    fi
  else
    warn "  hyprctl dispatch failed — log out and back in to restore shell"
  fi
else
  warn "  Could not auto-restart shell — log out and back in"
fi

echo ""
ok "═══════════════════════════════════════════"
ok "  omartia-dots-remux uninstalled!"
ok "═══════════════════════════════════════════"
echo ""
info "Backup preserved at: $LATEST_BACKUP"
info "To remove backup: rm -rf $BACKUP_DIR"
