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

# Parse args
for arg in "$@"; do
  case "$arg" in
    -y|--yes) YES=true ;;
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

# ──────────────────────────────────────────────
# Preflight checks
# ──────────────────────────────────────────────

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

if ! command -v quickshell &>/dev/null && ! command -v qs &>/dev/null; then
  err "quickshell not found — install it first: https://quickshell.outfoxxed.me"
  exit 1
fi
ok "Quickshell found"

# ──────────────────────────────────────────────
# Install dependencies
# ──────────────────────────────────────────────

info "Checking dependencies..."

DEPS_PKGS=()
for pkg in cmake ninja base-devel \
  qt6-base qt6-declarative qt6-svg qt6-shadertools qt6-multimedia qt6-wayland qt6-5compat \
  aubio libqalculate libpipewire lm_sensors \
  grim slurp wl-clipboard libnotify dart-sass cliphist fuzzel; do
  if ! pacman -Qi "$pkg" &>/dev/null; then
    DEPS_PKGS+=("$pkg")
  fi
done

if [[ ${#DEPS_PKGS[@]} -gt 0 ]]; then
  info "Installing: ${DEPS_PKGS[*]}"
  sudo pacman -S --noconfirm "${DEPS_PKGS[@]}"
  ok "Dependencies installed"
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
  info "Installing AUR packages: ${AUR_PKGS[*]}"
  "$AUR_HELPER" -S --noconfirm --needed "${AUR_PKGS[@]}"
  ok "AUR packages installed"
fi

# ──────────────────────────────────────────────
# Install Caelestia Shell
# ──────────────────────────────────────────────

CAELESTIA_DIR="$HOME/.config/quickshell/caelestia"

if [[ -d "$CAELESTIA_DIR" ]]; then
  warn "Caelestia Shell already installed at $CAELESTIA_DIR"
  if confirm "Reinstall/update?"; then
    info "Updating Caelestia Shell..."
    cd "$CAELESTIA_DIR"
    git pull --ff-only || warn "Git pull failed — using existing version"
    cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/ \
      || { err "cmake configure failed"; exit 1; }
    cmake --build build \
      || { err "cmake build failed"; exit 1; }
    sudo cmake --install build \
      || { err "cmake install failed"; exit 1; }
    ok "Caelestia Shell updated"
  fi
else
  info "Installing Caelestia Shell..."
  mkdir -p "$HOME/.config/quickshell"
  cd "$HOME/.config/quickshell"
  git clone https://github.com/caelestia-dots/shell.git caelestia \
    || { err "git clone failed — check your network connection"; exit 1; }
  cd caelestia
  cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/ \
    || { err "cmake configure failed"; exit 1; }
  cmake --build build \
    || { err "cmake build failed — check build logs above"; exit 1; }
  sudo cmake --install build \
    || { err "cmake install failed"; exit 1; }
  ok "Caelestia Shell installed"
fi

cd "$REPO_DIR"

# ──────────────────────────────────────────────
# Backup existing configs
# ──────────────────────────────────────────────

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

# ──────────────────────────────────────────────
# Install config files
# ──────────────────────────────────────────────

info "Installing config files..."

# Hypr configs — only copy if not present (first install), never silently overwrite
for f in hyprland.lua autostart.lua looknfeel.lua; do
  if [[ ! -f "$HOME/.config/hypr/$f" ]]; then
    cp "$REPO_DIR/config/hypr/$f" "$HOME/.config/hypr/$f"
    ok "  hypr/$f (new)"
  else
    warn "  hypr/$f exists — skipped (edit manually if needed)"
  fi
done

for f in monitors.lua input.lua bindings.lua; do
  if [[ ! -f "$HOME/.config/hypr/$f" ]]; then
    cp "$REPO_DIR/config/hypr/$f" "$HOME/.config/hypr/$f"
    ok "  hypr/$f (new)"
  else
    warn "  hypr/$f exists — skipped (edit manually if needed)"
  fi
done

# Caelestia shell.json
mkdir -p "$HOME/.config/caelestia"
cp "$REPO_DIR/config/caelestia/shell.json" "$HOME/.config/caelestia/shell.json"

# If omarchy preinstalls were removed, hide those apps from Caelestia's launcher
# (omarchy-remove-preinstalls only removes user-level .desktop files, but
# /usr/share/omarchy/applications/ still has them and Caelestia reads all XDG entries)
if [[ -f "$HOME/.local/state/omarchy/preinstalls-removed" ]]; then
  OMARCHY_APPS_DIR="/usr/share/omarchy/applications"
  if [[ -d "$OMARCHY_APPS_DIR" ]]; then
    HIDDEN_IDS=()
    for f in "$OMARCHY_APPS_DIR"/*.desktop; do
      [[ -f "$f" ]] || continue
      id=$(basename "$f" .desktop)
      HIDDEN_IDS+=("$id")
    done
    if [[ ${#HIDDEN_IDS[@]} -gt 0 ]]; then
      HIDDEN_JSON=$(printf '%s\n' "${HIDDEN_IDS[@]}" | python3 -c "
import sys, json
ids = [line.strip() for line in sys.stdin if line.strip()]
print(json.dumps(ids))
")
      python3 -c "
import json
with open('$HOME/.config/caelestia/shell.json') as f:
    cfg = json.load(f)
cfg.setdefault('launcher', {})['hiddenApps'] = $HIDDEN_JSON
with open('$HOME/.config/caelestia/shell.json', 'w') as f:
    json.dump(cfg, f, indent=4)
"
      ok "  Hidden ${#HIDDEN_IDS[@]} omarchy preinstall apps from launcher"
    fi
  fi
fi
ok "  caelestia/shell.json"

# Omarchy shell.json — disable conflicting plugins
mkdir -p "$HOME/.config/omarchy"
cp "$REPO_DIR/config/omarchy/shell.json" "$HOME/.config/omarchy/shell.json"
ok "  omarchy/shell.json (plugins disabled)"

# Caelestia systemd service — auto-restarts on crash or package update
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
ExecStart=${QS_BIN} -c caelestia
Restart=on-failure
RestartSec=2
Environment=QT_QPA_PLATFORM=wayland

[Install]
WantedBy=graphical-session.target
EOF
systemctl --user daemon-reload
systemctl --user enable caelestia-shell.service
ok "  caelestia-shell.service (auto-restart enabled, binary: $QS_BIN)"

# ──────────────────────────────────────────────
# Install theme bridge hook
# ──────────────────────────────────────────────

info "Installing theme bridge hook..."

HOOK_DIR="$HOME/.config/omarchy/hooks/theme-set.d"
mkdir -p "$HOOK_DIR"
cp "$REPO_DIR/hooks/theme-set.d/caelestia-sync.sh" "$HOOK_DIR/caelestia-sync.sh"
chmod +x "$HOOK_DIR/caelestia-sync.sh"
ok "Theme bridge hook installed"

# ──────────────────────────────────────────────
# Run initial theme sync
# ──────────────────────────────────────────────

info "Syncing current theme to Caelestia..."

if [[ -f "$HOME/.local/state/omarchy/current/theme/colors.toml" ]]; then
  bash "$HOOK_DIR/caelestia-sync.sh"
  ok "Theme synced"
else
  warn "No active theme found — run 'omarchy-theme-set <name>' then this script again"
fi

# ──────────────────────────────────────────────
# Done
# ──────────────────────────────────────────────

echo ""
ok "═══════════════════════════════════════════"
ok "  omartia-dots-remux installed!"
ok "═══════════════════════════════════════════"
echo ""
info "What changed:"
info "  • omarchy-shell disabled (all plugins off)"
info "  • Caelestia Shell installed (bar, lock, launcher, dashboard)"
info "  • Theme bridge installed (omarchy themes → Caelestia colors)"
info "  • Backups at: $BACKUP_PATH"
echo ""
info "Next steps:"
info "  1. Edit ~/.config/hypr/monitors.lua for your displays"
info "  2. Edit ~/.config/hypr/input.lua for your keyboard"
info "  3. Log out and back in"
info "  4. Test: SUPER+Space (launcher), SUPER+L (lock)"
info "  5. Test: omarchy-theme-set <theme> (verify colors update)"
echo ""
info "To uninstall: $REPO_DIR/uninstall.sh"
