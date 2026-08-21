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

# Refresh package databases — fresh installs often have empty or stale sync
# DBs, which makes every later 'pacman -S' fail with "target not found".
# The shell-restart guard hook isn't in place yet at this point (it gets
# installed by this script), but it's not needed either: caelestia-shell
# isn't running on a fresh target, so an update can't kill it mid-flight.
info "Refreshing package databases..."
if $DRY_RUN; then
  info "[dry-run] would run: sudo pacman -Sy --noconfirm"
else
  run_sudo pacman -Sy --noconfirm
fi

# Bring the base system level with the repos before layering the remux on top
if command -v omarchy-update &>/dev/null; then
  if confirm "Run omarchy-update first (recommended on fresh installs)?"; then
    info "Running omarchy-update..."
    if $DRY_RUN; then
      info "[dry-run] would run: omarchy-update"
    else
      omarchy-update || warn "omarchy-update failed — continuing anyway"
    fi
  fi
fi

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
    # Atomic swap: installing stable resolves the conflict by removing the git
    # variant within one transaction, so omarchy's 'quickshell' dependency is
    # satisfied throughout (a separate -Rns step would break it)
    run_sudo pacman -S --ask 4 --noconfirm quickshell
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
o.bind("SUPER + SPACE", "Caelestia launcher", hl.dsp.global("caelestia:launcher"))
o.bind("SUPER + ALT + SPACE", "Omartia menu", "omartia-menu")
o.bind("SUPER + N", "Notifications shade", hl.dsp.global("caelestia:sidebar"))
o.bind("SUPER + ALT + D", "Dashboard", hl.dsp.global("caelestia:dashboard"))
hl.unbind("SUPER + CTRL + L")
o.bind("SUPER + CTRL + L", "Lock system", hl.dsp.global("caelestia:lock"))
hl.unbind("SUPER + K")
o.bind("SUPER + K", "Keybindings", "omartia-keybinds")
o.bind("SUPER + ESCAPE", "Power menu", "omartia-power")
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
  if grep -q 'sleep 3 && pkill' "$AUTOSTART_FILE" 2>/dev/null; then
    # Upgrade path: replace the old injected block. Killing the omarchy shell
    # after launch no longer works — omarchy-launch-shell is a supervisor loop
    # that respawns quickshell when it dies.
    if $DRY_RUN; then
      info "[dry-run] would replace outdated Caelestia autostart block"
    else
      info "  Replacing outdated Caelestia autostart block..."
      sed -i '/^-- omartia-dots-remux: Caelestia Shell (auto-injected)/,/^end)$/d' "$AUTOSTART_FILE"
      cat >> "$AUTOSTART_FILE" << 'CAELESTIA_AUTOSTART'

-- omartia-dots-remux: Caelestia Shell (auto-injected)
-- Replaces omarchy-shell. The default autostart is stubbed out in
-- hyprland.lua, so the non-shell parts it used to launch are replicated here.
hl.on("hyprland.start", function()
  hl.exec_cmd("bash -c 'systemctl --user import-environment $(env | cut -d\"=\" -f 1) && dbus-update-activation-environment --systemd --all && systemctl --user start caelestia-shell.service'")
  hl.exec_cmd("omarchy-provision-first-run")
  hl.exec_cmd("omarchy-powerprofiles-init")
  hl.exec_cmd(o.launch("omarchy-hyprland-monitor-watch"))
  hl.exec_cmd(o.launch("udiskie --automount --no-notify --no-tray"))
  hl.exec_cmd("sleep 2 && omarchy-hook post-boot")
end)
CAELESTIA_AUTOSTART
    fi
    ok "  hypr/autostart.lua (updated)"
  elif ! grep -q "caelestia-shell" "$AUTOSTART_FILE" 2>/dev/null; then
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
-- Replaces omarchy-shell. The default autostart is stubbed out in
-- hyprland.lua, so the non-shell parts it used to launch are replicated here.
hl.on("hyprland.start", function()
  hl.exec_cmd("bash -c 'systemctl --user import-environment $(env | cut -d\"=\" -f 1) && dbus-update-activation-environment --systemd --all && systemctl --user start caelestia-shell.service'")
  hl.exec_cmd("omarchy-provision-first-run")
  hl.exec_cmd("omarchy-powerprofiles-init")
  hl.exec_cmd(o.launch("omarchy-hyprland-monitor-watch"))
  hl.exec_cmd(o.launch("udiskie --automount --no-notify --no-tray"))
  hl.exec_cmd("sleep 2 && omarchy-hook post-boot")
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
#
# The stub MUST be injected after the bootstrap.lua dofile line: bootstrap
# clears package.loaded for all default.hypr.* modules on every config load and
# reload, so a stub placed before it (e.g. at the top of the file) is wiped
# before require("default.hypr.omarchy") loads the real autostart.
HYPRLAND_FILE="$HOME/.config/hypr/hyprland.lua"
if [[ -f "$HYPRLAND_FILE" ]]; then
  if grep -q 'package.loaded\["default.hypr.autostart"\] = true' "$HYPRLAND_FILE" 2>/dev/null; then
    warn "  hyprland.lua already has Caelestia autostart override — skipped"
  elif $DRY_RUN; then
    info "[dry-run] would patch hyprland.lua (disable default autostart)"
  else
    # python3 exits non-zero if no injection point is found
    if python3 - "$HYPRLAND_FILE" << 'STUBPY'
import sys

path = sys.argv[1]
with open(path) as f:
    lines = f.readlines()

# Remove previously injected stubs (any placement), then strip leading blanks
marker = 'package.loaded["default.hypr.autostart"]'
lines = [l for l in lines if marker not in l and "Caelestia: prevent default omarchy autostart" not in l]
while lines and lines[0].strip() == "":
    lines.pop(0)

stub = [
    "-- Caelestia: prevent default omarchy autostart (Caelestia handles shell launch).\n",
    "-- Must be set AFTER bootstrap.lua: it clears package.loaded for default.hypr.*\n",
    "-- on every load/reload, so a stub placed before it gets wiped.\n",
    'package.loaded["default.hypr.autostart"] = true\n',
    "\n",
]

# Insert after the bootstrap dofile line; fall back to right before Omarchy's
# defaults are required.
idx = next((i for i, l in enumerate(lines) if "default/hypr/bootstrap.lua" in l), None)
anchor = "after bootstrap.lua dofile"
if idx is None:
    idx = next((i for i, l in enumerate(lines) if 'require("default.hypr.omarchy")' in l), None)
    anchor = "before require(default.hypr.omarchy)"
if idx is None:
    sys.exit(1)

lines[idx + 1:idx + 1] = stub
with open(path, "w") as f:
    f.writelines(lines)
print(f"  injected {anchor}")
sys.exit(0)
STUBPY
    then
      ok "  hyprland.lua patched (default autostart disabled)"
    else
      err "  Could not patch hyprland.lua automatically — add this after"
      err "  bootstrap.lua loads and before require(\"default.hypr.omarchy\"):"
      err '    package.loaded["default.hypr.autostart"] = true'
    fi
  fi
fi

# Caelestia shell.json
if ! $DRY_RUN; then
  mkdir -p "$HOME/.config/caelestia"
  cp "$REPO_DIR/config/caelestia/shell.json" "$HOME/.config/caelestia/shell.json"
fi

# Caelestia per-monitor overlays (e.g. disable shell on secondary monitors)
if [[ -d "$REPO_DIR/config/caelestia/monitors" ]]; then
  if ! $DRY_RUN; then
    mkdir -p "$HOME/.config/caelestia/monitors"
    cp -r "$REPO_DIR/config/caelestia/monitors/." "$HOME/.config/caelestia/monitors/"
  fi
  ok "  caelestia/monitors overlays"
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
    # GPS tools (gpsd-clients)
    "xgps", "xgpsspeed",
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
# Install update guard (omarchy-restart-shell)
# ──────────────────────────────────────────────

info "Installing omarchy-update shell guard..."

if ! $DRY_RUN; then
  run_sudo install -m755 "$REPO_DIR/hooks/libalpm/omartia-guard-restart-shell.sh" /usr/local/bin/
  run_sudo install -m644 "$REPO_DIR/hooks/libalpm/omartia-restart-shell-guard.hook" /usr/share/libalpm/hooks/
  run_sudo /usr/local/bin/omartia-guard-restart-shell.sh
fi
ok "Update guard installed (blocks omarchy-update from relaunching omarchy-shell)"

# ──────────────────────────────────────────────
# Install omartia fuzzel menu suite
# ──────────────────────────────────────────────

info "Installing omartia menu suite..."

if ! $DRY_RUN; then
  mkdir -p "$HOME/.local/bin"
  for f in "$REPO_DIR"/scripts/omartia-*; do
    install -m755 "$f" "$HOME/.local/bin/"
  done
fi
ok "omartia menus installed (SUPER+ALT+SPACE root, SUPER+ESC power, SUPER+K keybinds)"

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
# Session-start preflight (black screen guard)
# Verifies the exact chain the NEXT login depends on: hyprland.lua stub
# placement, autostart.lua handler registration, upstream API presence,
# and the caelestia-shell.service unit. Any failure here means logging out
# could leave the session with no shell at all (the historic black screen).
# ──────────────────────────────────────────────

PREFLIGHT_LOG="$HOME/omartia-preflight.log"
PREFLIGHT_FAIL=0

if ! $DRY_RUN; then
  info "Running session-start preflight..."

  pf_pass() { echo "PASS: $*" | tee -a "$PREFLIGHT_LOG"; }
  pf_fail() { echo "FAIL: $*" | tee -a "$PREFLIGHT_LOG"; PREFLIGHT_FAIL=1; }

  : > "$PREFLIGHT_LOG"
  echo "omartia session-start preflight — $(date)" >> "$PREFLIGHT_LOG"

  HYPRLAND_FILE="$HOME/.config/hypr/hyprland.lua"
  AUTOSTART_FILE="$HOME/.config/hypr/autostart.lua"
  SERVICE_FILE="$HOME/.config/systemd/user/caelestia-shell.service"

  stub_report="$(python3 - "$HYPRLAND_FILE" <<'PFPY'
import sys

try:
    lines = open(sys.argv[1]).readlines()
except OSError:
    print("file-missing")
    sys.exit(0)

def find(pred):
    return next((i for i, l in enumerate(lines) if pred(l)), None)

boot = find(lambda l: "default/hypr/bootstrap.lua" in l)
stub = find(lambda l: 'package.loaded["default.hypr.autostart"]' in l)
req = find(lambda l: 'require("default.hypr.omarchy")' in l)

if boot is None:
    print("no-bootstrap-anchor")
elif req is None:
    print("no-omarchy-require")
elif stub is None:
    print("no-stub")
elif boot < stub < req:
    print(f"ok bootstrap=line {boot+1}, stub=line {stub+1}, omarchy=line {req+1}")
else:
    print(f"misplaced bootstrap=line {boot+1}, stub=line {stub+1}, omarchy=line {req+1}")
PFPY
)"
  case "$stub_report" in
    ok*) pf_pass "autostart stub placement ($stub_report)" ;;
    *) pf_fail "autostart stub: $stub_report (must sit after bootstrap.lua, before default.hypr.omarchy)" ;;
  esac

  if grep -q 'require("hypr.autostart")' "$HYPRLAND_FILE" 2>/dev/null; then
    pf_pass "hyprland.lua loads hypr.autostart"
  else
    pf_fail "hyprland.lua no longer requires hypr.autostart — upstream Omarchy layout changed"
  fi

  if [[ -f "$OMARCHY_PATH/default/hypr/helpers.lua" ]] && grep -q "function o.launch" "$OMARCHY_PATH/default/hypr/helpers.lua"; then
    pf_pass "o.launch helper present in omarchy defaults"
  else
    pf_fail "o.launch helper missing in $OMARCHY_PATH/default/hypr/helpers.lua — autostart.lua would abort on load"
  fi

  if grep -rq '"hyprland.start"' "$OMARCHY_PATH/default/hypr/" /usr/share/hypr/stubs/ 2>/dev/null; then
    pf_pass "hyprland.start event exists upstream"
  else
    pf_fail "hyprland.start event not found upstream — hl.on handler may never fire"
  fi

  if grep -q 'hl.on("hyprland.start"' "$AUTOSTART_FILE" 2>/dev/null && grep -q "caelestia-shell.service" "$AUTOSTART_FILE" 2>/dev/null; then
    pf_pass "autostart.lua registers the Caelestia launch handler"
  else
    pf_fail "autostart.lua missing Caelestia launch handler"
  fi

  LUAC_BIN="$(command -v luac5.4 || command -v luac5.3 || command -v luac || true)"
  if [[ -n "$LUAC_BIN" ]]; then
    if "$LUAC_BIN" -p "$AUTOSTART_FILE" >/dev/null 2>&1; then
      pf_pass "autostart.lua syntax valid"
    else
      pf_fail "autostart.lua has Lua syntax errors — it would abort silently on login"
    fi
  else
    echo "SKIP: no luac found — autostart.lua syntax unchecked" >> "$PREFLIGHT_LOG"
  fi

  QS_BIN_UNIT="$(sed -n 's/^ExecStart=//p' "$SERVICE_FILE" 2>/dev/null | cut -d' ' -f1 || true)"
  if [[ -n "$QS_BIN_UNIT" && -x "$QS_BIN_UNIT" ]]; then
    pf_pass "caelestia-shell.service ExecStart binary present ($QS_BIN_UNIT)"
  else
    pf_fail "caelestia-shell.service missing or its ExecStart binary is not executable"
  fi

  if systemctl --user is-enabled --quiet caelestia-shell.service 2>/dev/null; then
    pf_pass "caelestia-shell.service enabled"
  else
    pf_fail "caelestia-shell.service is not enabled"
  fi

  if systemd-analyze --user verify "$SERVICE_FILE" >/dev/null 2>&1; then
    pf_pass "caelestia-shell.service unit verifies"
  else
    pf_fail "systemd-analyze --user verify flagged caelestia-shell.service"
  fi

  echo "" >> "$PREFLIGHT_LOG"

  if [[ "$PREFLIGHT_FAIL" -eq 1 ]]; then
    err ""
    err "═══════════════════════════════════════════"
    err "  PREFLIGHT FAILED — ROLLING BACK SAFELY"
    err "═══════════════════════════════════════════"

    pf_rollback() {
      local f restored=0
      info "Restoring stock Omarchy startup chain..."
      for f in hyprland.lua autostart.lua bindings.lua; do
        if [[ -f "$BACKUP_PATH/$f" ]]; then
          cp "$BACKUP_PATH/$f" "$HOME/.config/hypr/$f"
          ok "  restored hypr/$f from backup"
          echo "ROLLBACK: restored hypr/$f from $BACKUP_PATH" >> "$PREFLIGHT_LOG"
          restored=1
        fi
      done
      if [[ "$restored" -eq 0 ]]; then
        python3 - "$HOME/.config/hypr/hyprland.lua" <<'PFUNSTUB'
import sys

path = sys.argv[1]
with open(path) as fh:
    lines = fh.readlines()
marker = 'package.loaded["default.hypr.autostart"]'
lines = [l for l in lines if marker not in l and "Caelestia: prevent default omarchy autostart" not in l]
with open(path, "w") as fh:
    fh.writelines(lines)
PFUNSTUB
        sed -i '/^-- omartia-dots-remux: Caelestia Shell (auto-injected)/,/^end)$/d' "$HOME/.config/hypr/autostart.lua" 2>/dev/null || true
        warn "  no backup found — stripped injected blocks instead"
        echo "ROLLBACK: no backup; stripped injections surgically" >> "$PREFLIGHT_LOG"
      fi
      systemctl --user disable --now caelestia-shell.service >/dev/null 2>&1 || true
      ok "  caelestia-shell.service disabled (stock omarchy-shell owns startup again)"
      echo "ROLLBACK: caelestia-shell.service disabled" >> "$PREFLIGHT_LOG"
    }
    pf_rollback

    err ""
    err "Your PC remains fully usable as stock Omarchy — logging out or rebooting is SAFE."
    err "Nothing is broken; the Caelestia switch was paused before it could break anything."
    err ""
    err "Failed checks:"
    grep '^FAIL' "$PREFLIGHT_LOG" | sed 's/^/  /' >&2
    err ""
    err "Send this log for help, or ask your AI agent to read it: $PREFLIGHT_LOG"
    err "Fixed something? Re-run: $REPO_DIR/install.sh"
    err "Want it fully removed? $REPO_DIR/uninstall.sh"
  else
    ok "Preflight passed: $(grep -c '^PASS' "$PREFLIGHT_LOG") checks OK (log: $PREFLIGHT_LOG)"
  fi
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
  info "Black screen after logout? Press Ctrl+Alt+F4 for a TTY, log in, then:"
  info "  cat ~/omartia-preflight.log && systemctl --user start caelestia-shell.service"
  echo ""

  # Auto-logout after 5 seconds so Caelestia Shell starts (preflight must pass)
  if [[ "$PREFLIGHT_FAIL" -eq 0 ]] && confirm "Log out now to start Caelestia Shell?"; then
    info "Logging out in 5 seconds... (press Ctrl+C to cancel)"
    sleep 5
    # End the session cleanly so sddm-helper exits 0 and SDDM relaunches:
    # dispatch exit / terminate-user kill uwsm outright, sddm-helper dies
    # non-zero and SDDM never respawns the greeter — black screen.
    if command -v omarchy-system-logout >/dev/null 2>&1; then
      omarchy-system-logout   # nohup'd: sleep 2 && uwsm stop
      exit 0
    fi
    loginctl terminate-user "$USER"
  fi
fi
