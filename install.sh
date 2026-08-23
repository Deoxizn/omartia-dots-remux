#!/usr/bin/env bash
# ███████╗████████╗███████╗██╗     ██╗      █████╗ ██████╗  ██████╗██╗  ██╗██╗   ██╗
# ██╔════╝╚══██╔══╝██╔════╝██║     ██║     ██╔══██╗██╔══██╗██╔════╝██║  ██║╚██╗ ██╔╝
# ███████╗   ██║   █████╗  ██║     ██║     ███████║██████╔╝██║     ███████║ ╚████╔╝
# ╚════██║   ██║   ██╔══╝  ██║     ██║     ██╔══██║██╔══██╗██║     ██╔══██║  ╚██╔╝
# ███████║   ██║   ███████╗███████╗███████╗██║  ██║██║  ██║╚██████╗██║  ██║   ██║
# ╚══════╝   ╚═╝   ╚══════╝╚══════╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝   ╚═╝

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
CACHYOS_KERNEL=false

# Parse args
for arg in "$@"; do
  case "$arg" in
    -y|--yes) YES=true ;;
    --skip-quickshell-check) SKIP_QS_CHECK=true ;;
    --dry-run) DRY_RUN=true ;;
    --cachyos-kernel) CACHYOS_KERNEL=true ;;
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

rebuild_initrd() {
  if ! mountpoint -q /boot; then
    warn "  /boot is not mounted — refusing to leave boot images half-built."
    warn "  Mount the ESP (e.g. mount /dev/nvme0n1p1 /boot) and rerun: sudo limine-mkinitcpio"
    return 1
  fi
  info "  Rebuilding initramfs (splash lives in there)..."
  if ! run_sudo limine-mkinitcpio; then
    warn "  limine-mkinitcpio FAILED — UKIs are stale. DO NOT reboot until a rebuild succeeds."
    warn "  Escape hatch: echo -e '[Daemon]\nTheme=omarchy' > /etc/plymouth/plymouthd.conf && sudo limine-mkinitcpio"
    return 1
  fi
}

# The mkinitcpio plymouth hook packs ONLY the active theme's directory
# (plus text/details fallbacks). A .plymouth whose ScriptFile points at
# another theme's dir ships an initramfs with no boot script at all:
# plymouth renders nothing, so splash AND LUKS password prompt are invisible
# — a black screen that looks like a dead boot. Refuse to activate any
# theme that isn't self-contained.
theme_selfcontained() {
  local dir="$1" name="$2" sf
  sf="$(sed -n 's/^ *ScriptFile *= *//p' "$dir/$name.plymouth" 2>/dev/null)"
  if [[ -z $sf ]]; then
    err "  $name.plymouth has no ScriptFile line"
    return 1
  fi
  case "$sf" in
    "$dir"/*) ;;
    *)
      err "  $name.plymouth ScriptFile ($sf) lives outside its own theme dir —"
      err "  the initramfs would ship without it (black screen where the LUKS"
      err "  prompt should be). Vendor the script into $dir instead."
      return 1 ;;
  esac
  if [[ ! -f $sf ]]; then
    err "  ScriptFile missing: $sf"
    return 1
  fi
  return 0
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

# Apply remux patches to the Caelestia Shell checkout. Kept as uncommitted
# working-tree changes so upstream `git pull --ff-only` keeps working.
apply_caelestia_patches() {
  local p
  for p in "$REPO_DIR"/patches/*.patch; do
    [[ -e $p ]] || return 0
    if git -C "$CAELESTIA_DIR" apply --check "$p" 2>/dev/null; then
      if $DRY_RUN; then
        info "[dry-run] would apply caelestia patch: $(basename "$p")"
      else
        git -C "$CAELESTIA_DIR" apply "$p" \
          && ok "  caelestia patch applied: $(basename "$p")" \
          || warn "  caelestia patch failed to apply: $(basename "$p")"
      fi
    elif git -C "$CAELESTIA_DIR" apply --reverse --check "$p" 2>/dev/null; then
      info "  caelestia patch already applied: $(basename "$p")"
    else
      warn "  caelestia patch no longer fits upstream ($(basename "$p")) — skipping"
    fi
  done
}

if [[ -d "$CAELESTIA_DIR" ]]; then
  warn "Caelestia Shell already installed at $CAELESTIA_DIR"
  if $DRY_RUN; then
    info "[dry-run] would update Caelestia Shell"
  elif confirm "Reinstall/update?"; then
    info "Updating Caelestia Shell..."
    cd "$CAELESTIA_DIR"
    git pull --ff-only || warn "Git pull failed — using existing version"
    apply_caelestia_patches
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
    apply_caelestia_patches
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

# Auto-detect monitor config for monitors.lua (only on first install).
# Hyprland's "auto" scale guesses from panel DPI and overshoots on many
# 1080p laptops (everything looks zoomed in), so we write EXPLICIT numbers.
# Interactive installs get asked; -y takes the detected defaults.
# Note: corner rounding in looknfeel.lua is scale-aware either way.
if [[ ! -f "$HOME/.config/hypr/monitors.lua" ]]; then
  if $DRY_RUN; then
    info "[dry-run] would auto-detect monitors for monitors.lua"
  elif command -v hyprctl &>/dev/null && [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
    info "  Detecting monitors..."
    MONITOR_JSON=$(hyprctl monitors -j 2>/dev/null)
    if [[ -n "$MONITOR_JSON" ]]; then
      read -r DETECTED_SCALE DETECTED_GDK <<< "$(echo "$MONITOR_JSON" | python3 -c "
import sys, json
try:
    monitors = json.load(sys.stdin)
except Exception:
    print(1, 1); sys.exit()
max_h = max((m.get('height', 0) for m in monitors), default=1080)
if max_h <= 1200:
    scale, gdk = 1, 1
elif max_h <= 1600:
    scale, gdk = 1.25, 1
elif max_h <= 2160:
    scale, gdk = 1.5, 1
else:
    scale, gdk = 2, 2
print(scale, gdk)
" 2>/dev/null || echo "1 1")"
      MONITOR_SCALE="${DETECTED_SCALE:-1}"
      GDK_SCALE_INT="${DETECTED_GDK:-1}"

      if ! $YES; then
        echo ""
        info "Display scaling (Hyprland 'auto' often picks oversized scales on laptops)"
        read -rp "  Monitor scale [${MONITOR_SCALE}]: " SCALE_REPLY
        if [[ "$SCALE_REPLY" == "auto" ]]; then
          MONITOR_SCALE="auto"
        elif [[ "$SCALE_REPLY" =~ ^[0-9]+([.][0-9]+)?$ && -n "$SCALE_REPLY" ]]; then
          MONITOR_SCALE="$SCALE_REPLY"
        fi
        read -rp "  GTK scale / GDK_SCALE, integer [${GDK_SCALE_INT}]: " GDK_REPLY
        [[ "$GDK_REPLY" =~ ^[12]$ ]] && GDK_SCALE_INT="$GDK_REPLY"
        echo ""
      fi

      # "auto" is a string in Lua; numeric scales are written bare
      if [[ "$MONITOR_SCALE" == "auto" ]]; then
        SCALE_LUA="\"auto\""
      else
        SCALE_LUA="$MONITOR_SCALE"
      fi

      cat > "$HOME/.config/hypr/monitors.lua" << MONITORS_EOF
-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- List current monitors and supported resolutions with: hyprctl monitors all

-- Explicit scale instead of Hyprland's DPI-guessed "auto" (which tends to
-- oversize UI on mid-DPI laptop panels). Corner rounding in looknfeel.lua
-- adapts to this value automatically.
local omarchy_gdk_scale = ${GDK_SCALE_INT}
local omarchy_monitor_scale = ${SCALE_LUA}

hl.env("GDK_SCALE", tostring(omarchy_gdk_scale))
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = omarchy_monitor_scale })
MONITORS_EOF
      ok "  hypr/monitors.lua (monitor scale=${MONITOR_SCALE}, GDK_SCALE=${GDK_SCALE_INT})"
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
for f in hyprland.lua autostart.lua looknfeel.lua input.lua hypridle.conf; do
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
# Brand default fastfetch (Stellarchy OS line)
# ──────────────────────────────────────────────

# Users who never touched fastfetch have no ~/.config/fastfetch/config.jsonc,
# so seed one from the system default with the OS line and logo branded. A
# user-level copy always wins over /etc and survives omarchy-settings-dev updates.
info "Fastfetch branding..."

FF_DIR="$HOME/.config/fastfetch"
if [[ -f $FF_DIR/config.jsonc ]]; then
  warn "  custom fastfetch config found — left untouched"
elif [[ ! -f /etc/fastfetch/config.jsonc ]]; then
  warn "  /etc/fastfetch/config.jsonc not found — skipping"
else
  if ! $DRY_RUN; then
    mkdir -p "$FF_DIR"
    cp /etc/fastfetch/config.jsonc "$FF_DIR/config.jsonc"
    cp "$REPO_DIR/stellarchy-nobg.png" "$FF_DIR/stellarchy-nobg.png"
    sed -i \
      -e 's/Omarchy \$version/Stellarchy (Omarchy \$version)/' \
      -e 's|"type": "file"|"type": "sixel"|' \
      -e 's|"source": "~/.config/omarchy/branding/about.txt"|"source": "~/.config/fastfetch/stellarchy-nobg.png",\n    "width": 70,\n    "height": 30|' \
      "$FF_DIR/config.jsonc"
  fi
  ok "  seeded ~/.config/fastfetch/config.jsonc (system default + Stellarchy line + logo)"
fi

# ──────────────────────────────────────────────
# Branding (screensaver.txt / about.txt) — Stellarchy wordmark.
# Installs when missing or still stock Omarchy art; never overwrites
# genuine user customization.
# ──────────────────────────────────────────────

info "Branding..."
BRANDING_DIR="$HOME/.config/omarchy/branding"
declare -A BRAND_STOCK=(
  ["screensaver.txt"]="/usr/share/omarchy/logo.txt"
  ["about.txt"]="/usr/share/omarchy/icon.txt"
)
for f in screensaver.txt about.txt; do
  src="$REPO_DIR/branding/$f"
  dst="$BRANDING_DIR/$f"
  stock="${BRAND_STOCK[$f]}"
  [[ -f $src ]] || continue
  if [[ ! -f $dst ]] || { [[ -n $stock && -f $stock ]] && cmp -s "$dst" "$stock"; }; then
    if ! $DRY_RUN; then
      mkdir -p "$BRANDING_DIR"
      cp "$src" "$dst"
    fi
    ok "  branding/$f installed"
  elif cmp -s "$dst" "$src" || grep -q 'Stellarchy' "$dst"; then
    ok "  branding/$f already Stellarchy"
  else
    warn "  branding/$f customized — left untouched"
  fi
done
unset BRAND_STOCK

# ──────────────────────────────────────────────
# Plymouth splash — stellarchy theme.
# Own theme dir (package updates can't touch it) holding our logo plus
# copies of Omarchy's small support PNGs; ScriptFile stays pointed at
# Omarchy's script so upstream fixes flow through. Initrd rebuilt only
# when something actually changed (the splash loads from initramfs).
# ──────────────────────────────────────────────

info "Plymouth splash..."
PLYMOUTH_SRC="$REPO_DIR/branding/plymouth"
PLYMOUTH_DST="/usr/share/plymouth/themes/stellarchy"
OMARCHY_PLY="/usr/share/plymouth/themes/omarchy"

if ! $DRY_RUN; then
  NEEDS_INITRD=false
  if [[ -d $OMARCHY_PLY ]]; then
    run_sudo mkdir -p "$PLYMOUTH_DST"
    for pair in "stellarchy-logo.png:logo.png" "stellarchy.plymouth:stellarchy.plymouth"; do
      src="$PLYMOUTH_SRC/${pair%%:*}"
      dst="$PLYMOUTH_DST/${pair##*:}"
      if [[ ! -f $dst ]] || ! cmp -s "$src" "$dst"; then
        run_sudo cp "$src" "$dst"
        NEEDS_INITRD=true
      fi
    done
    # Support art (lock/bullets/progress) and boot script mirror Omarchy's;
    # refreshed on drift. The script MUST be vendored here: the initramfs
    # hook only packs this theme's dir, so a cross-dir ScriptFile reference
    # would leave the splash (and LUKS prompt) invisible.
    for f in bullet.png entry.png lock.png progress_bar.png progress_box.png omarchy.script; do
      if [[ -f $OMARCHY_PLY/$f ]] && ! cmp -s "$OMARCHY_PLY/$f" "$PLYMOUTH_DST/$f"; then
        run_sudo cp "$OMARCHY_PLY/$f" "$PLYMOUTH_DST/$f"
        NEEDS_INITRD=true
      fi
    done
    if ! theme_selfcontained "$PLYMOUTH_DST" stellarchy; then
      warn "  Aborting install before an unbootable reboot — fix the theme, then rerun the installer."
      exit 1
    fi
    if ! grep -q '^Theme=stellarchy' /etc/plymouth/plymouthd.conf 2>/dev/null; then
      run_sudo plymouth-set-default-theme stellarchy
      NEEDS_INITRD=true
    fi
    if [[ ${NEEDS_INITRD:-false} == true ]]; then
      if ! rebuild_initrd; then
        warn "  Aborting install before an unbootable reboot — fix the above, then rerun the installer."
        exit 1
      fi
    fi
    ok "Plymouth splash: stellarchy theme active"
  else
    warn "  Omarchy plymouth theme not found — skipping (splash stays stock)"
  fi
else
  info "[dry-run] would install stellarchy plymouth theme + set default + rebuild initrd"
fi

# ──────────────────────────────────────────────
# Install omartia fuzzel menu suite
# ──────────────────────────────────────────────

info "Installing omartia menu suite..."

if ! $DRY_RUN; then
  mkdir -p "$HOME/.local/bin"
  install -m755 "$REPO_DIR/scripts/caelestia-system-lock" "$HOME/.local/bin/"
  for f in "$REPO_DIR"/scripts/omartia-*; do
    install -m755 "$f" "$HOME/.local/bin/"
  done
fi
ok "omartia menus installed (SUPER+ALT+SPACE root, SUPER+ESC power, SUPER+K keybinds)"
ok "caelestia-system-lock installed (lock keybind + hypridle lock_cmd)"

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
# Optional: CachyOS BORE kernel (chaotic-aur, prebuilt)
# Desktop/gaming scheduler tuning. The stock Arch kernel is never removed —
# both entries appear in the Limine menu, so a bad update is a menu pick away.
# Opt-in only: interactive prompt, or --cachyos-kernel for scripted installs.
# Never triggered by -y alone.
# ──────────────────────────────────────────────

setup_chaotic_kernel() {
  local assent="${1:-false}"

  if pacman -Q linux-cachyos-bore &>/dev/null; then
    ok "CachyOS BORE kernel already installed — updates flow via pacman -Syu"
    return 0
  fi

  if ! $assent; then
    info "Optional: CachyOS BORE kernel via chaotic-aur (prebuilt, stock kernel stays as fallback)"
    confirm "Install linux-cachyos-bore now?" || { info "Skipping CachyOS kernel"; return 0; }
  else
    info "Installing CachyOS BORE kernel (--cachyos-kernel)"
  fi

  if ! grep -q '^\[chaotic-aur\]' /etc/pacman.conf; then
    info "  Adding chaotic-aur repo..."
    run_sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
    run_sudo pacman-key --lsign-key 3056513887B78AEB
    run_sudo bash -c "pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'"
    run_sudo cp /etc/pacman.conf /etc/pacman.conf.omartia-backup
    printf '\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist\n' | run_sudo tee -a /etc/pacman.conf >/dev/null
  else
    ok "  chaotic-aur already configured"
  fi

  run_sudo pacman -Sy --noconfirm
  run_sudo pacman -S --ask 4 --noconfirm linux-cachyos-bore linux-cachyos-bore-headers

  # Regenerate entries so the BORE subentry exists, then aim the static
  # default_entry header at it. The index counts every entry line in
  # limine.conf (groups, kernels, snapshots) in document order — computing
  # it live beats hardcoding a number. The header survives limine-update;
  # only omarchy-refresh-limine resets it from Omarchy's template.
  run_sudo limine-update
  if [[ -f /boot/limine.conf ]]; then
    bore_idx=$(awk '/^[[:space:]]*\//{i++} /^[[:space:]]*\/\/linux-cachyos-bore[[:space:]]*$/{print i; exit}' /boot/limine.conf)
    if [[ -n $bore_idx ]] && ! grep -q "^default_entry:[[:space:]]*$bore_idx\$" /boot/limine.conf; then
      info "  default boot entry -> linux-cachyos-bore (#$bore_idx)"
      run_sudo sed -i "s/^default_entry:.*/default_entry: $bore_idx/" /boot/limine.conf
    fi
  fi

  ok "BORE kernel installed and set as default boot entry; stock kernel kept as fallback"
}

if $CACHYOS_KERNEL || ! $YES; then
  setup_chaotic_kernel "$CACHYOS_KERNEL"
fi

echo ""

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
  info "Caelestia didn't start after install? Press Ctrl+Alt+F4 for a TTY, log in, then:"
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
