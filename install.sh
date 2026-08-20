#!/usr/bin/env bash
# omartia-dots-remux installer
# Replaces omarchy-shell with Caelestia Shell + theme bridge
# https://github.com/deoxizn/omartia-dots-remux

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKUP_DIR="$HOME/.config/omartia-dots-remux-backup"
BACKUP_TS="$(date +%Y%m%d%H%M%S)"
BACKUP_PATH="$BACKUP_DIR/$BACKUP_TS"
OMARCHY_PATH="${OMARCHY_PATH:-/usr/share/omarchy}"
YES=false
SKIP_QS_CHECK=false
DRY_RUN=false

# Parse args
for arg in "$@"; do
  case "$arg" in
    -y|--yes) YES=true ;;
    --skip-quickshell-check) SKIP_QS_CHECK=true ;;
    --dry-run) DRY_RUN=true ;;
  esac
done

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${CYAN}[omartia]${NC} $*"; }
ok()    { echo -e "${GREEN}[omartia]${NC} $*"; }
warn()  { echo -e "${YELLOW}[omartia]${NC} $*"; }
err()   { echo -e "${RED}[omartia]${NC} $*" >&2; }

confirm() {
  if $YES; then return 0; fi
  read -rp "$1 [y/N] " REPLY
  [[ "$REPLY" =~ ^[Yy]$ ]]
}

run() {
  if $DRY_RUN; then
    info "[dry-run] would run: $*"
    return 0
  fi
  "$@"
}

run_sudo() {
  if $DRY_RUN; then
    info "[dry-run] would run: sudo $*"
    return 0
  fi
  sudo "$@"
}

# ──────────────────────────────────────────────
# Preflight checks
# ──────────────────────────────────────────────

if $DRY_RUN; then
  echo ""
  ok "═══════════════════════════════════════════"
  ok "  DRY RUN MODE — no changes will be made"
  ok "═══════════════════════════════════════════"
  echo ""
fi

if [[ ! -d "$OMARCHY_PATH/default" ]]; then
  err "Omarchy not found at $OMARCHY_PATH"
  err "Install omarchy first: https://github.com/basecamp/omarchy"
  exit 1
fi
ok "Omarchy found at $OMARCHY_PATH"

if [[ "$(id -u)" -eq 0 ]]; then
  err "Do not run this installer as root"
  exit 1
fi

MIN_QS_VERSION="0.3.0"

if ! command -v quickshell &>/dev/null && ! command -v qs &>/dev/null; then
  err "quickshell not found — install it first: https://quickshell.outfoxxed.me"
  exit 1
fi
ok "Quickshell found"

# Detect quickshell-git — offer to switch to stable
if ! $SKIP_QS_CHECK && pacman -Qi quickshell-git &>/dev/null; then
  echo ""
  warn "quickshell-git detected — this is a bleeding-edge package known to break"
  warn "omarchy itself depends on stable 'quickshell' from extra, not the git variant"
  if $DRY_RUN; then
    warn "[dry-run] would offer to switch to stable quickshell"
  elif confirm "Remove quickshell-git and install stable quickshell?"; then
    info "Switching to stable quickshell..."
    # omarchy-dev depends on quickshell (provided by quickshell-git), remove it first
    if pacman -Qi omarchy-dev &>/dev/null; then
      warn "omarchy-dev depends on quickshell-git — removing omarchy-dev first"
      run_sudo pacman -Rns omarchy-dev --noconfirm
      mkdir -p "$HOME/.local/state/omartia-dots-remux"
      touch "$HOME/.local/state/omartia-dots-remux/omarchy-dev-removed"
    fi
    run_sudo pacman -Rns quickshell-git --noconfirm
    run_sudo pacman -S --noconfirm quickshell
    # Reinstall omarchy-dev now that stable quickshell provides the dependency
    if [[ -f "$HOME/.local/state/omartia-dots-remux/omarchy-dev-removed" ]]; then
      info "Reinstalling omarchy-dev (provides omarchy-launch-* commands)..."
      run_sudo pacman -S --noconfirm omarchy-dev
      rm -f "$HOME/.local/state/omartia-dots-remux/omarchy-dev-removed"
      ok "omarchy-dev reinstalled"
    fi
    ok "Switched to stable quickshell"
  else
    warn "Continuing with quickshell-git — you may hit build or runtime issues"
  fi
  echo ""
fi

# Version compatibility check
if ! $SKIP_QS_CHECK; then
  QS_VERSION_RAW=$(qs --version 2>/dev/null || quickshell --version 2>/dev/null || echo "")
  if [[ -n "$QS_VERSION_RAW" ]]; then
    QS_VERSION=$(echo "$QS_VERSION_RAW" | grep -oP '[\d]+\.[\d]+\.[\d]+' | head -1)
    if [[ -n "$QS_VERSION" ]]; then
      if printf '%s\n%s\n' "$MIN_QS_VERSION" "$QS_VERSION" | sort -V | head -1 | grep -q "$MIN_QS_VERSION"; then
        ok "Quickshell version $QS_VERSION (>= $MIN_QS_VERSION required)"
      else
        err "Quickshell $QS_VERSION is too old — need >= $MIN_QS_VERSION"
        err "Update: sudo pacman -Syu quickshell"
        exit 1
      fi
    fi
  fi
fi

# ──────────────────────────────────────────────
# Install dependencies
# ──────────────────────────────────────────────

info "Checking dependencies..."

DEPS_PKGS=()
for pkg in cmake ninja base-devel \
  qt6-base qt6-declarative qt6-svg qt6-shadertools qt6-multimedia qt6-wayland qt6-5compat \
  aubio libqalculate libpipewire lm_sensors \
  grim slurp wl-clipboard libnotify dart-sass cliphist fuzzel ttf-material-symbols-variable; do
  if ! pacman -Qi "$pkg" &>/dev/null; then
    DEPS_PKGS+=("$pkg")
  fi
done

if [[ ${#DEPS_PKGS[@]} -gt 0 ]]; then
  if $DRY_RUN; then
    info "[dry-run] would install: ${DEPS_PKGS[*]}"
  else
    info "Installing: ${DEPS_PKGS[*]}"
    run_sudo pacman -S --noconfirm "${DEPS_PKGS[@]}"
    ok "Dependencies installed"
  fi
else
  ok "All dependencies already installed"
fi

# AUR packages
# - libcava: provides the .pc file Caelestia needs (Arch's cava is just the binary)
# - caelestia-cli: wallpaper, scheme, shell control commands
AUR_PKGS=()
for pkg in libcava caelestia-cli; do
  if ! pacman -Qi "$pkg" &>/dev/null; then
    AUR_PKGS+=("$pkg")
  fi
done

if [[ ${#AUR_PKGS[@]} -gt 0 ]]; then
  if command -v yay &>/dev/null; then
    AUR_HELPER="yay"
  elif command -v paru &>/dev/null; then
    AUR_HELPER="paru"
  else
    err "AUR packages needed (${AUR_PKGS[*]}) but neither yay nor paru found"
    err "Install yay: https://github.com/Jguer/yay"
    exit 1
  fi
  if $DRY_RUN; then
    info "[dry-run] would install AUR packages: ${AUR_PKGS[*]}"
  else
    info "Installing AUR packages: ${AUR_PKGS[*]}"
    "$AUR_HELPER" -S --noconfirm --needed "${AUR_PKGS[@]}"
    ok "AUR packages installed"
  fi
fi

# ──────────────────────────────────────────────
# Install Caelestia Shell
# ──────────────────────────────────────────────

CAELESTIA_DIR="$HOME/.config/quickshell/caelestia"

if [[ -d "$CAELESTIA_DIR" ]]; then
  warn "Caelestia Shell already installed at $CAELESTIA_DIR"
  if $DRY_RUN; then
    info "[dry-run] would update Caelestia Shell"
  elif confirm "Reinstall/update?"; then
    info "Updating Caelestia Shell..."
    cd "$CAELESTIA_DIR"
    git pull --ff-only || warn "Git pull failed — using existing version"
    cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/ \
      || { err "cmake configure failed"; err "Hint: this may be a quickshell version issue"; err "If on quickshell-git, try: sudo pacman -S quickshell"; exit 1; }
    cmake --build build \
      || { err "cmake build failed"; err "Hint: this may be a quickshell version issue"; err "If on quickshell-git, try: sudo pacman -S quickshell"; exit 1; }
    run_sudo cmake --install build \
      || { err "cmake install failed"; exit 1; }
    ok "Caelestia Shell updated"
  fi
else
  if $DRY_RUN; then
    info "[dry-run] would clone and build Caelestia Shell"
  else
    info "Installing Caelestia Shell..."
    mkdir -p "$HOME/.config/quickshell"
    cd "$HOME/.config/quickshell"
    git clone https://github.com/caelestia-dots/shell.git caelestia \
      || { err "git clone failed — check your network connection"; exit 1; }
    cd caelestia
    cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/ \
      || { err "cmake configure failed"; err "Hint: this may be a quickshell version issue"; err "If on quickshell-git, try: sudo pacman -S quickshell"; exit 1; }
    cmake --build build \
      || { err "cmake build failed — check build logs above"; err "Hint: this may be a quickshell version issue"; err "If on quickshell-git, try: sudo pacman -S quickshell"; exit 1; }
    run_sudo cmake --install build \
      || { err "cmake install failed"; exit 1; }
    ok "Caelestia Shell installed"
  fi
fi

cd "$REPO_DIR"

# ──────────────────────────────────────────────
# Backup existing configs
# ──────────────────────────────────────────────

if $DRY_RUN; then
  info "[dry-run] would backup configs to $BACKUP_PATH"
else
  info "Backing up existing configs to $BACKUP_PATH"

  mkdir -p "$BACKUP_PATH"

  # Backup hypr configs
  for f in "$HOME/.config/hypr"/*.lua "$HOME/.config/hypr"/*.conf; do
    [[ -f "$f" ]] && cp "$f" "$BACKUP_PATH/"
  done

  # Backup omarchy shell.json
  [[ -f "$HOME/.config/omarchy/shell.json" ]] && cp "$HOME/.config/omarchy/shell.json" "$BACKUP_PATH/"

  # Backup caelestia dir
  [[ -d "$HOME/.config/caelestia" ]] && cp -r "$HOME/.config/caelestia" "$BACKUP_PATH/caelestia"

  # Backup caelestia systemd service
  [[ -f "$HOME/.config/systemd/user/caelestia-shell.service" ]] && cp "$HOME/.config/systemd/user/caelestia-shell.service" "$BACKUP_PATH/"

  ok "Backup complete"
fi

# ──────────────────────────────────────────────
# Install config files
# ──────────────────────────────────────────────

if $DRY_RUN; then
  info "[dry-run] would install config files..."
else
  info "Installing config files..."
fi

# Auto-detect monitor config for monitors.lua (only on first install)
if [[ ! -f "$HOME/.config/hypr/monitors.lua" ]]; then
  if $DRY_RUN; then
    info "[dry-run] would auto-detect monitors for monitors.lua"
  elif command -v hyprctl &>/dev/null && [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
    info "  Detecting monitors..."
    MONITOR_JSON=$(hyprctl monitors -j 2>/dev/null)
    if [[ -n "$MONITOR_JSON" ]]; then
      MAX_RES=$(echo "$MONITOR_JSON" | python3 -c "
import sys, json
monitors = json.load(sys.stdin)
max_h = max((m.get('height', 0) for m in monitors), default=1080)
if max_h <= 1080:
    print(1)
elif max_h <= 1440:
    print(1.5)
else:
    print(2)
" 2>/dev/null || echo "1")
      cat > "$HOME/.config/hypr/monitors.lua" << MONITORS_EOF
-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- List current monitors and supported resolutions with: hyprctl monitors all

local omarchy_gdk_scale = ${MAX_RES}
local omarchy_monitor_scale = "auto"

hl.env("GDK_SCALE", tostring(omarchy_gdk_scale))
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = omarchy_monitor_scale })
MONITORS_EOF
      ok "  hypr/monitors.lua (auto-detected, GDK_SCALE=${MAX_RES})"
    else
      cp "$REPO_DIR/config/hypr/monitors.lua" "$HOME/.config/hypr/monitors.lua"
      ok "  hypr/monitors.lua (fallback default)"
    fi
  else
    cp "$REPO_DIR/config/hypr/monitors.lua" "$HOME/.config/hypr/monitors.lua"
    ok "  hypr/monitors.lua (default)"
  fi
else
  warn "  hypr/monitors.lua exists — skipped"
fi

# Hypr configs — only copy if not present (first install), never silently overwrite
for f in hyprland.lua autostart.lua looknfeel.lua input.lua; do
  if [[ ! -f "$HOME/.config/hypr/$f" ]]; then
    if ! $DRY_RUN; then
      cp "$REPO_DIR/config/hypr/$f" "$HOME/.config/hypr/$f"
    fi
    ok "  hypr/$f (new)"
  else
    warn "  hypr/$f exists — skipped"
  fi
done

# Patch bindings.lua — inject Caelestia launcher/lock bindings into existing config
BINDINGS_FILE="$HOME/.config/hypr/bindings.lua"
if [[ ! -f "$BINDINGS_FILE" ]]; then
  if ! $DRY_RUN; then
    cp "$REPO_DIR/config/hypr/bindings.lua" "$BINDINGS_FILE"
  fi
  ok "  hypr/bindings.lua (new)"
else
  if ! grep -q "caelestia:launcher" "$BINDINGS_FILE" 2>/dev/null; then
    if $DRY_RUN; then
      info "[dry-run] would patch hypr/bindings.lua with Caelestia bindings"
    else
      info "  Patching hypr/bindings.lua with Caelestia bindings..."
      cat >> "$BINDINGS_FILE" << 'CAELESTIA_BINDINGS'

-- omartia-dots-remux: Caelestia bindings (auto-injected)
hl.unbind("SUPER + SPACE")
hl.unbind("SUPER + ALT + SPACE")
o.bind("SUPER + SPACE", "Caelestia launcher", hl.dsp.global("caelestia:launcher"))
o.bind("SUPER + ALT + SPACE", "Session menu", hl.dsp.global("caelestia:session"))
o.bind("SUPER + N", "Notifications shade", hl.dsp.global("caelestia:sidebar"))
o.bind("SUPER + ALT + D", "Dashboard", hl.dsp.global("caelestia:dashboard"))
hl.unbind("SUPER + CTRL + L")
o.bind("SUPER + CTRL + L", "Lock system", hl.dsp.global("caelestia:lock"))
CAELESTIA_BINDINGS
    fi
    ok "  hypr/bindings.lua (patched)"
  else
    warn "  hypr/bindings.lua already has Caelestia bindings — skipped"
  fi
fi

# Patch autostart.lua — inject Caelestia shell launch into existing config
AUTOSTART_FILE="$HOME/.config/hypr/autostart.lua"
if [[ ! -f "$AUTOSTART_FILE" ]]; then
  if ! $DRY_RUN; then
    cp "$REPO_DIR/config/hypr/autostart.lua" "$AUTOSTART_FILE"
  fi
  ok "  hypr/autostart.lua (new)"
else
  if ! grep -q "caelestia-shell" "$AUTOSTART_FILE" 2>/dev/null; then
    if $DRY_RUN; then
      info "[dry-run] would patch hypr/autostart.lua with Caelestia shell launch"
    else
      info "  Patching hypr/autostart.lua with Caelestia shell launch..."

      # Comment out the omarchy quickshell bar launch (Caelestia provides its own bar)
      if grep -q 'quickshell.*config/quickshell/bar' "$AUTOSTART_FILE" 2>/dev/null; then
        sed -i 's|^\([^#].*quickshell.*config/quickshell/bar.*\)$|-- omartia-dots-remux: disabled (Caelestia provides bar)\n-- \1|' "$AUTOSTART_FILE"
        ok "  hypr/autostart.lua (omarchy bar disabled)"
      fi

      cat >> "$AUTOSTART_FILE" << 'CAELESTIA_AUTOSTART'

-- omartia-dots-remux: Caelestia Shell (auto-injected)
-- Replaces omarchy-shell (plugins disabled via shell.json)
-- Commands are chained to ensure env is imported BEFORE the service starts
-- After Caelestia starts, kill the omarchy shell (default autostart launches it)
hl.on("hyprland.start", function()
  hl.exec_cmd("bash -c 'systemctl --user import-environment $(env | cut -d\"=\" -f 1) && dbus-update-activation-environment --systemd --all && systemctl --user start caelestia-shell.service && sleep 3 && pkill -f \"quickshell -n -p .*/omarchy/shell\" 2>/dev/null'")
end)
CAELESTIA_AUTOSTART
    fi
    ok "  hypr/autostart.lua (patched)"
  else
    warn "  hypr/autostart.lua already has Caelestia shell — skipped"
  fi
fi

# Prevent omarchy shell from launching (Caelestia replaces it)
# The default omarchy autostart calls omarchy-launch-shell which has a supervision
# loop that respawns the shell when killed. Instead of replacing system binaries
# (which breaks on pacman updates), prevent the autostart module from loading
# via Lua's package.loaded mechanism.
HYPRLAND_FILE="$HOME/.config/hypr/hyprland.lua"
if [[ -f "$HYPRLAND_FILE" ]]; then
  if ! grep -q 'package.loaded\["default.hypr.autostart"\]' "$HYPRLAND_FILE" 2>/dev/null; then
    if $DRY_RUN; then
      info "[dry-run] would patch hyprland.lua (disable default autostart)"
    else
      # Insert at the top of the file, before any other code
      sed -i '1i\-- Caelestia: prevent default omarchy autostart (Caelestia handles shell launch)\npackage.loaded["default.hypr.autostart"] = function() end\n' "$HYPRLAND_FILE"
    fi
    ok "  hyprland.lua patched (default autostart disabled)"
  else
    warn "  hyprland.lua already has Caelestia autostart override — skipped"
  fi
fi

# Caelestia shell.json
if ! $DRY_RUN; then
  mkdir -p "$HOME/.config/caelestia"
  cp "$REPO_DIR/config/caelestia/shell.json" "$HOME/.config/caelestia/shell.json"
fi

# Hide system utility apps and omarchy preinstalls from Caelestia's launcher
# These are desktop files that ship with packages but shouldn't appear in a launcher
if ! $DRY_RUN; then
  python3 - "$HOME/.config/caelestia/shell.json" << 'HIDDENPY'
import json, os, sys, glob

config_path = sys.argv[1]
with open(config_path) as f:
    cfg = json.load(f)

# Base list: system utility desktop file IDs that should never appear in launcher
hidden = [
    # Avahi network tools
    "avahi-discover", "bssh", "bvnc",
    # Dev/build helpers
    "cmake-gui",
    # System monitor (user accesses via terminal)
    "btop",
    # Printer config
    "cups", "system-config-printer",
    # System utilities
    "lstopo", "limine-snapper-restore", "user-dirs-update-gtk", "uuctl",
    # Terminal variants (main "foot" is kept)
    "foot-server", "footclient",
    # Qt test/video utilities
    "qv4l2", "qvidcap",
    # Gnome helper apps
    "gnome-disk-image-mounter", "gnome-disk-image-writer",
    "nautilus-autorun-software",
    # Internal components that shouldn't be launched directly
    "gcr-prompter", "gcr-viewer",
    "xdg-desktop-portal-gtk", "org.freedesktop.Xwayland",
    "org.gnupg.pinentry-qt", "org.quickshell",
    # Fcitx5 (input method — configured via system settings, not launcher)
    "org.fcitx.Fcitx5", "fcitx5-configtool",
    "org.fcitx.fcitx5-qt5-gui-wrapper", "org.fcitx.fcitx5-qt6-gui-wrapper",
    "fcitx5-wayland-launcher",
    # Evince previewer (main Evince is kept)
    "org.gnome.Evince-previewer",
    # imv variants
    "imv-dir",
]

# Also hide any omarchy preinstall apps that still have desktop files
omarchy_dir = "/usr/share/omarchy/applications"
if os.path.isdir(omarchy_dir):
    for f in glob.glob(os.path.join(omarchy_dir, "*.desktop")):
        app_id = os.path.splitext(os.path.basename(f))[0]
        if app_id not in hidden:
            hidden.append(app_id)

cfg.setdefault("launcher", {})["hiddenApps"] = hidden
with open(config_path, "w") as f:
    json.dump(cfg, f, indent=4)
HIDDENPY
fi
ok "  caelestia/shell.json"

# Omarchy shell.json — disable conflicting plugins
if ! $DRY_RUN; then
  mkdir -p "$HOME/.config/omarchy"
  cp "$REPO_DIR/config/omarchy/shell.json" "$HOME/.config/omarchy/shell.json"
fi
ok "  omarchy/shell.json (plugins disabled)"

# Caelestia systemd service — auto-restarts on crash or package update
if ! $DRY_RUN; then
  mkdir -p "$HOME/.config/systemd/user"
  if command -v qs &>/dev/null; then
    QS_BIN="$(command -v qs)"
  elif command -v quickshell &>/dev/null; then
    QS_BIN="$(command -v quickshell)"
  else
    err "Neither qs nor quickshell found in PATH"
    exit 1
  fi
  cat > "$HOME/.config/systemd/user/caelestia-shell.service" <<EOF
[Unit]
Description=Caelestia Shell
After=graphical-session.target
PartOf=graphical-session.target

[Service]
Type=simple
ExecStartPre=/usr/bin/bash -c 'for i in 1 2 3 4 5; do [ -n "\$WAYLAND_DISPLAY" ] && exit 0; sleep 0.5; done; exit 1'
ExecStart=${QS_BIN} -c caelestia
Restart=on-failure
RestartSec=2
Environment=QT_QPA_PLATFORM=wayland
Environment=QT_WAYLAND_DISABLE_WINDOWDECORATION=1

[Install]
WantedBy=graphical-session.target
EOF
  systemctl --user daemon-reload
  systemctl --user enable caelestia-shell.service
fi
ok "  caelestia-shell.service (auto-restart enabled)"

# ──────────────────────────────────────────────
# Install theme bridge hook
# ──────────────────────────────────────────────

info "Installing theme bridge hook..."

HOOK_DIR="$HOME/.config/omarchy/hooks/theme-set.d"
if ! $DRY_RUN; then
  mkdir -p "$HOOK_DIR"
  cp "$REPO_DIR/hooks/theme-set.d/caelestia-sync.sh" "$HOOK_DIR/caelestia-sync.sh"
  chmod +x "$HOOK_DIR/caelestia-sync.sh"
fi
ok "Theme bridge hook installed"

# ──────────────────────────────────────────────
# Run initial theme sync
# ──────────────────────────────────────────────

info "Syncing current theme to Caelestia..."

if [[ -f "$HOME/.local/state/omarchy/current/theme/colors.toml" ]]; then
  if ! $DRY_RUN; then
    bash "$HOOK_DIR/caelestia-sync.sh"
  fi
  ok "Theme synced"
else
  warn "No active theme found — run 'omarchy-theme-set <name>' then this script again"
fi

# ──────────────────────────────────────────────
# Done
# ──────────────────────────────────────────────

echo ""
if $DRY_RUN; then
  ok "═══════════════════════════════════════════"
  ok "  DRY RUN COMPLETE — no changes were made"
  ok "═══════════════════════════════════════════"
  echo ""
  info "Everything looks good. Run without --dry-run to install:"
  info "  $REPO_DIR/install.sh -y"
else
  ok "═══════════════════════════════════════════"
  ok "  omartia-dots-remux installed!"
  ok "═══════════════════════════════════════════"
  echo ""
  info "What changed:"
  info "  • Caelestia Shell installed (bar, lock, launcher, dashboard)"
  info "  • Theme bridge installed (omarchy themes → Caelestia colors)"
  info "  • Keybindings patched (SUPER+Space → Caelestia launcher)"
  info "  • omarchy-shell default autostart disabled (package.loaded override)"
  info "  • Backups at: $BACKUP_PATH"
  echo ""
  info "Next steps:"
  info "  1. Test: SUPER+Space (launcher), SUPER+L (lock)"
  info "  2. Test: omarchy-theme-set <theme> (verify colors update)"
  info "  3. If anything is wrong, run: $REPO_DIR/uninstall.sh"
  echo ""
  info "To uninstall: $REPO_DIR/uninstall.sh"
  echo ""

  # Auto-logout after 5 seconds so Caelestia Shell starts
  if confirm "Log out now to start Caelestia Shell?"; then
    info "Logging out in 5 seconds... (press Ctrl+C to cancel)"
    sleep 5
    loginctl terminate-user "$USER"
  fi
fi
