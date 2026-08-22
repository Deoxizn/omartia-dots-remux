#!/usr/bin/env bash
# ███████╗████████╗███████╗██╗     ██╗      █████╗ ██████╗  ██████╗██╗  ██╗██╗   ██╗
# ██╔════╝╚══██╔══╝██╔════╝██║     ██║     ██╔══██╗██╔══██╗██╔════╝██║  ██║╚██╗ ██╔╝
# ███████╗   ██║   █████╗  ██║     ██║     ███████║██████╔╝██║     ███████║ ╚████╔╝
# ╚════██║   ██║   ██╔══╝  ██║     ██║     ██╔══██║██╔══██╗██║     ██╔══██║  ╚██╔╝
# ███████║   ██║   ███████╗███████╗███████╗██║  ██║██║  ██║╚██████╗██║  ██║   ██║
# ╚══════╝   ╚═╝   ╚══════╝╚══════╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝   ╚═╝

# omartia-dots-remux upgrader
# Syncs an existing remux install with the repo: refreshes menu scripts,
# theme bridge hook, update guard, merges lua config updates (personal
# edits preserved via 3-way merge) and keeps keybinds in sync via a
# managed block. For fresh installs use install.sh instead.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
DRY_RUN=false
NO_PULL=false
ADOPT_LUA=false
BORE=false
PLYMOUTH=false

for arg in "$@"; do
  case "$arg" in
    -n|--dry-run) DRY_RUN=true ;;
    --no-pull) NO_PULL=true ;;
    --adopt-lua) ADOPT_LUA=true ;;
    --bore) BORE=true ;;
    --plymouth) PLYMOUTH=true ;;
    -h|--help)
      echo "Usage: ./upgrade.sh [--dry-run] [--no-pull] [--adopt-lua] [--bore] [--plymouth]"
      echo "  --dry-run    show what would change without touching anything"
      echo "  --no-pull    skip git pull (sync from current checkout)"
      echo "  --adopt-lua  adopt repo versions of hypr lua configs that have no"
      echo "               sync history (your current file is backed up first)"
      echo "  --bore       opt into the CachyOS BORE kernel: adds chaotic-aur, installs"
      echo "               linux-cachyos-bore + headers (prebuilt), makes it the default"
      echo "               Limine entry. Stock Arch kernel stays installed as fallback."
      echo "  --plymouth   adopt the Stellarchy boot splash (rebuilds initramfs)."
      exit 0 ;;
  esac
done

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${CYAN}[omartia]${NC} $*"; }
ok()    { echo -e "${GREEN}[omartia]${NC} $*"; }
warn()  { echo -e "${YELLOW}[omartia]${NC} $*"; }
err()   { echo -e "${RED}[omartia]${NC} $*" >&2; }

changed=0

copy_if_changed() { # <src> <dst> <label>
  local src="$1" dst="$2" label="$3"
  if [[ ! -f $dst ]]; then
    if $DRY_RUN; then
      info "  [dry-run] would install $label"
    else
      mkdir -p "$(dirname "$dst")"
      install -m755 "$src" "$dst"
      ok "  installed $label"
    fi
    changed=$((changed+1))
  elif ! cmp -s "$src" "$dst"; then
    if $DRY_RUN; then
      info "  [dry-run] would update $label"
    else
      install -m755 "$src" "$dst"
      ok "  updated $label"
    fi
    changed=$((changed+1))
  else
    ok "  $label up to date"
  fi
}

# ──────────────────────────────────────────────
# Preflight
# ──────────────────────────────────────────────

if [[ ! -f "$HOME/.config/caelestia/shell.json" ]]; then
  err "Caelestia config not found — is the remux installed?"
  err "Run ./install.sh first for a fresh install."
  exit 1
fi

# ──────────────────────────────────────────────
# Pull latest
# ──────────────────────────────────────────────

if $NO_PULL; then
  info "Skipping git pull (--no-pull)"
elif git -C "$REPO_DIR" rev-parse --is-inside-work-tree &>/dev/null; then
  branch="$(git -C "$REPO_DIR" symbolic-ref --short HEAD)"
  if [[ $(git -C "$REPO_DIR" status --porcelain --untracked-files=no | wc -l) -gt 0 ]]; then
    warn "Local uncommitted changes — skipping pull (resolve or stash first)"
  else
    info "Pulling latest ($branch)..."
    if git -C "$REPO_DIR" pull --ff-only origin "$branch"; then
      ok "  repo up to date"
    else
      err "  pull failed — syncing from current checkout instead"
    fi
  fi
else
  warn "Not a git clone — skipping pull"
fi

echo ""

# ──────────────────────────────────────────────
# Menu suite scripts → ~/.local/bin
# ──────────────────────────────────────────────

info "Menu suite scripts:"

shopt -s nullglob
repo_scripts=("$REPO_DIR"/scripts/omartia-*)
if (( ${#repo_scripts[@]} == 0 )); then
  warn "  no scripts found in repo"
fi
for src in "${repo_scripts[@]}"; do
  copy_if_changed "$src" "$HOME/.local/bin/$(basename "$src")" "$(basename "$src")"
done
# Scripts removed upstream but still installed locally
for dst in "$HOME/.local/bin/"omartia-*; do
  [[ -f "$REPO_DIR/scripts/$(basename "$dst")" ]] || warn "  $(basename "$dst") no longer in repo — left in place, remove manually if unwanted"
done
shopt -u nullglob

echo ""

# ──────────────────────────────────────────────
# Theme bridge hook
# ──────────────────────────────────────────────

info "Theme bridge hook:"
copy_if_changed "$REPO_DIR/hooks/theme-set.d/caelestia-sync.sh" \
  "$HOME/.config/omarchy/hooks/theme-set.d/caelestia-sync.sh" "caelestia-sync.sh"

echo ""

# ──────────────────────────────────────────────
# Update guard
# ──────────────────────────────────────────────

info "Update guard:"
guard_src="$REPO_DIR/hooks/libalpm/omartia-guard-restart-shell.sh"
hook_src="$REPO_DIR/hooks/libalpm/omartia-restart-shell-guard.hook"
guard_dst="/usr/local/bin/omartia-guard-restart-shell.sh"
hook_dst="/usr/share/libalpm/hooks/omartia-restart-shell-guard.hook"

sync_root_file() { # <src> <dst> <label> <mode>
  local src="$1" dst="$2" label="$3" mode="$4"
  if ! cmp -s "$src" "$dst"; then
    if $DRY_RUN; then
      info "  [dry-run] would update $label"
    else
      sudo install -m"$mode" "$src" "$dst"
      ok "  updated $label"
    fi
    changed=$((changed+1))
  else
    ok "  $label up to date"
  fi
}

if [[ -f $guard_dst ]]; then
  sync_root_file "$guard_src" "$guard_dst" "guard script" 755
  sync_root_file "$hook_src" "$hook_dst" "libalpm hook" 644
  if ! $DRY_RUN; then
    sudo "$guard_dst" </dev/null || true
  fi
else
  warn "  guard not installed — skipping (run install.sh to add it)"
fi

echo ""

# ──────────────────────────────────────────────
# Hypr Lua configs — 3-way merge from repo
# Personal edits are preserved; repo changes are merged in using the
# last-synced copy as merge base. monitors.lua and input.lua are skipped
# (device-specific); bindings.lua is handled separately below.
# On conflict your live file is left untouched and a .conflict copy is
# written for manual resolution.
# ──────────────────────────────────────────────

SKIP_LUA=(monitors.lua input.lua bindings.lua)
BASE_DIR="$HOME/.config/hypr/.omartia-base"
info "Hypr Lua configs (merge from repo):"

shopt -s nullglob
for src in "$REPO_DIR"/config/hypr/*.lua; do
  name="$(basename "$src")"
  # skip device-specific / specially-handled files
  skip=false
  for s in "${SKIP_LUA[@]}"; do [[ $name == "$s" ]] && skip=true; done
  $skip && continue

  dst="$HOME/.config/hypr/$name"
  base="$BASE_DIR/$name"
  mkdir -p "$BASE_DIR"

  if [[ ! -f $dst ]]; then
    if $DRY_RUN; then
      info "  [dry-run] would install $name"
    else
      install -m644 "$src" "$dst"
      cp -f "$src" "$base"
      ok "  installed $name"
    fi
    changed=$((changed+1))
  elif cmp -s "$src" "$dst"; then
    cp -f "$src" "$base"   # keep merge base fresh
    ok "  $name up to date"
  elif [[ ! -f $base ]]; then
    # No sync history: cannot tell your edits from stale repo state — don't touch.
    warn "  $name differs and has no sync history — left untouched"
    warn "    review: diff \"$src\" \"$dst\""
    warn "    or adopt repo version (backs up yours): ./upgrade.sh --adopt-lua"
  else
    tmp_current="$(mktemp)"
    cp "$dst" "$tmp_current"
    if git merge-file -L yours -L base -L repo "$tmp_current" "$base" "$src" >/dev/null 2>&1; then
      if $DRY_RUN; then
        info "  [dry-run] would merge repo changes into $name (your edits kept, backup: hypr/$name.pre-upgrade.bak)"
      else
        cp "$dst" "$dst.pre-upgrade.bak"
        install -m644 "$tmp_current" "$dst"
        cp -f "$src" "$base"
        ok "  merged repo changes into $name (backup: hypr/$name.pre-upgrade.bak)"
      fi
      changed=$((changed+1))
    else
      cp "$tmp_current" "$HOME/.config/hypr/$name.conflict"
      warn "  $name has conflicts between your edits and repo changes — NOT applied"
      warn "    resolve manually: hypr/$name.conflict → hypr/$name (markers: yours/base/repo)"
      changed=$((changed+1))
    fi
    rm -f "$tmp_current"
  fi
done
shopt -u nullglob

# --adopt-lua: explicitly take repo version for files without sync history
if $ADOPT_LUA; then
  info "Adopting repo versions (--adopt-lua):"
  shopt -s nullglob
  for src in "$REPO_DIR"/config/hypr/*.lua; do
    name="$(basename "$src")"
    skip=false
    for s in "${SKIP_LUA[@]}"; do [[ $name == "$s" ]] && skip=true; done
    $skip && continue

    dst="$HOME/.config/hypr/$name"
    base="$BASE_DIR/$name"
    [[ -f $dst && ! -f $base ]] || continue
    if $DRY_RUN; then
      info "  [dry-run] would adopt repo $name (backup: hypr/$name.pre-upgrade.bak)"
    else
      cp "$dst" "$dst.pre-upgrade.bak"
      install -m644 "$src" "$dst"
      cp -f "$src" "$base"
      ok "  adopted repo $name (backup: hypr/$name.pre-upgrade.bak)"
    fi
    changed=$((changed+1))
  done
  shopt -u nullglob
fi

echo ""

# ──────────────────────────────────────────────
# Corner rounding (looknfeel.lua) — managed block overlay
# Scale-aware rounding matching Caelestia panels (~12 logical px on the
# highest-scale monitor), recomputed on monitor hotplug so mixed-DPI
# multi-monitor setups and different laptops all land correctly.
# Appended if missing, refreshed in place when the repo updates it.
# Personal code elsewhere in looknfeel.lua stays untouched.
# ──────────────────────────────────────────────

LOOKNFEEL_FILE="$HOME/.config/hypr/looknfeel.lua"
REPO_LOOKNFEEL="$REPO_DIR/config/hypr/looknfeel.lua"
info "Corner rounding:"

ROUND_BEGIN="-- BEGIN omartia-dots-remux managed rounding (auto-synced by upgrade.sh)"
ROUND_END="-- END omartia-dots-remux managed rounding"

if [[ ! -f $REPO_LOOKNFEEL ]]; then
  warn "  repo looknfeel.lua not found — skipping"
elif [[ ! -f $LOOKNFEEL_FILE ]]; then
  ok "  no live looknfeel.lua — the lua merge section installs one"
else
  round_block="$(mktemp)"
  awk -v b="$ROUND_BEGIN" -v e="$ROUND_END" '$0 == b {f = 1} f {print} $0 == e {exit}' "$REPO_LOOKNFEEL" > "$round_block"

  rb_line=$(grep -nF -e "$ROUND_BEGIN" "$LOOKNFEEL_FILE" | head -1 | cut -d: -f1) || true
  re_line=$(grep -nF -e "$ROUND_END" "$LOOKNFEEL_FILE" | head -1 | cut -d: -f1) || true

  if [[ -n $rb_line && -n $re_line ]]; then
    old_block="$(mktemp)"
    sed -n "${rb_line},${re_line}p" "$LOOKNFEEL_FILE" > "$old_block"
    if cmp -s "$old_block" "$round_block"; then
      ok "  managed rounding block up to date"
    elif $DRY_RUN; then
      info "  [dry-run] would update managed rounding block"
      changed=$((changed+1))
    else
      tmp="$(mktemp)"
      { head -n $((rb_line - 1)) "$LOOKNFEEL_FILE"; cat "$round_block"; tail -n +"$((re_line + 1))" "$LOOKNFEEL_FILE"; } > "$tmp"
      mv "$tmp" "$LOOKNFEEL_FILE"
      ok "  managed rounding block updated — run 'hyprctl reload' to apply"
      changed=$((changed+1))
    fi
    rm -f "$old_block"
  elif [[ -n $rb_line || -n $re_line ]]; then
    warn "  malformed managed rounding block (only one marker found) — left untouched"
  elif grep -q "apply_rounding" "$LOOKNFEEL_FILE"; then
    warn "  unmanaged rounding code found in looknfeel.lua — left untouched"
    warn "    (wrap it in the managed markers yourself, or delete it and re-run upgrade.sh)"
  else
    if $DRY_RUN; then
      info "  [dry-run] would append managed rounding block ($(wc -l < "$round_block") lines) to hypr/looknfeel.lua"
    else
      { echo ""; cat "$round_block"; } >> "$LOOKNFEEL_FILE"
      ok "  managed rounding block appended — run 'hyprctl reload' to apply"
    fi
    changed=$((changed+1))
  fi
  rm -f "$round_block"
fi

echo ""

# ──────────────────────────────────────────────
# Keybinds (bindings.lua) — managed block overlay
# Your personal lines stay untouched above the managed block; the full repo
# keybind set is appended inside it. Hyprland applies binds top-down with
# last-wins, so repo keybinds always take effect on every machine.
# ──────────────────────────────────────────────

BINDINGS_FILE="$HOME/.config/hypr/bindings.lua"
REPO_BINDINGS="$REPO_DIR/config/hypr/bindings.lua"
info "Keybinds:"

if [[ ! -f $BINDINGS_FILE ]]; then
  if $DRY_RUN; then
    info "  [dry-run] would install bindings.lua from repo"
  else
    install -m644 "$REPO_BINDINGS" "$BINDINGS_FILE"
    ok "  installed bindings.lua from repo"
  fi
  changed=$((changed+1))
elif [[ ! -f $REPO_BINDINGS ]]; then
  warn "  repo bindings.lua not found — skipping"
else
  MANAGED_BEGIN="-- BEGIN omartia-dots-remux managed keybinds (auto-synced by upgrade.sh — personal edits belong outside this block)"
  MANAGED_END="-- END omartia-dots-remux managed keybinds"

  # Strip legacy auto-injected omartia blocks (predecessors of the managed
  # block). Duplicates make toggle binds (sidebar/dashboard) fire twice and
  # appear dead. A legacy block = its marker comment plus the command lines
  # after it, up to the next blank line.
  if grep -q -- "-- omartia-dots-remux: .*auto-injected" "$BINDINGS_FILE"; then
    if $DRY_RUN; then
      info "  [dry-run] would remove legacy omartia auto-injected binding block(s)"
      changed=$((changed+1))
    else
      tmp="$(mktemp)"
      awk '
        /^-- omartia-dots-remux: .*auto-injected/ { skip=1; next }
        skip && /^[[:space:]]*$/ { skip=0; next }
        skip { next }
        { print }
      ' "$BINDINGS_FILE" > "$tmp"
      mv "$tmp" "$BINDINGS_FILE"
      ok "  removed legacy auto-injected binding block(s) — run 'hyprctl reload' to apply"
      changed=$((changed+1))
    fi
  fi

  section_file="$(mktemp)"
  {
    printf '%s\n' "$MANAGED_BEGIN"
    cat "$REPO_BINDINGS"
    printf '%s\n' "$MANAGED_END"
  } > "$section_file"

  begin_line=$(grep -nF -e "$MANAGED_BEGIN" "$BINDINGS_FILE" | head -1 | cut -d: -f1) || true
  end_line=$(grep -nF -e "$MANAGED_END" "$BINDINGS_FILE" | head -1 | cut -d: -f1) || true

  if [[ -n $begin_line && -n $end_line ]]; then
    old_section="$(mktemp)"
    sed -n "${begin_line},${end_line}p" "$BINDINGS_FILE" > "$old_section"
    if cmp -s "$old_section" "$section_file"; then
      ok "  keybinds up to date"
    elif $DRY_RUN; then
      info "  [dry-run] would update managed keybind block; changes:"
      diff --unified=0 "$old_section" "$section_file" | sed 's/^/      /' || true
      changed=$((changed+1))
    else
      tmp="$(mktemp)"
      { head -n $((begin_line - 1)) "$BINDINGS_FILE"; cat "$section_file"; tail -n +"$((end_line + 1))" "$BINDINGS_FILE"; } > "$tmp"
      mv "$tmp" "$BINDINGS_FILE"
      ok "  managed keybind block updated — run 'hyprctl reload' to apply"
      changed=$((changed+1))
    fi
    rm -f "$old_section"
  else
    if $DRY_RUN; then
      info "  [dry-run] would append managed keybind block ($(wc -l < "$REPO_BINDINGS") lines) to hypr/bindings.lua"
    else
      { echo ""; cat "$section_file"; } >> "$BINDINGS_FILE"
      ok "  managed keybind block appended — run 'hyprctl reload' to apply"
    fi
    changed=$((changed+1))
  fi
  rm -f "$section_file"
fi

echo ""

# ──────────────────────────────────────────────
# Lock script + hypridle — keep remux-owned files current
# caelestia-system-lock is referenced by the power menu, the lock keybind and
# hypridle's lock_cmd; hypridle.conf wires idle lock/dpms/suspend to it.
# User edits to hypridle.conf are preserved: repo version lands as .new.
# ──────────────────────────────────────────────

info "Lock / idle:"

if [[ -f $REPO_DIR/scripts/caelestia-system-lock ]]; then
  if $DRY_RUN; then
    info "  [dry-run] would update ~/.local/bin/caelestia-system-lock"
  else
    install -m755 "$REPO_DIR/scripts/caelestia-system-lock" "$HOME/.local/bin/"
    ok "  ~/.local/bin/caelestia-system-lock updated"
  fi
fi

HYPRIDLE_SRC="$REPO_DIR/config/hypr/hypridle.conf"
HYPRIDLE_DST="$HOME/.config/hypr/hypridle.conf"
if [[ -f $HYPRIDLE_SRC ]]; then
  if [[ ! -f $HYPRIDLE_DST ]]; then
    if ! $DRY_RUN; then install -m644 "$HYPRIDLE_SRC" "$HYPRIDLE_DST"; fi
    ok "  hypr/hypridle.conf installed"
  elif ! cmp -s "$HYPRIDLE_SRC" "$HYPRIDLE_DST"; then
    if ! $DRY_RUN; then install -m644 "$HYPRIDLE_SRC" "$HOME/.config/hypr/hypridle.conf.new"; fi
    warn "  hypridle.conf differs from repo — review hypr/hypridle.conf.new (your file untouched)"
  else
    ok "  hypridle.conf up to date"
  fi
fi

echo ""

# ──────────────────────────────────────────────
# Fastfetch branding (Stellarchy OS line) — seed once if user never
# customized fastfetch. Mirrors install.sh; never touches an existing config.
# ──────────────────────────────────────────────

FF_DIR="$HOME/.config/fastfetch"
info "Fastfetch branding:"
if [[ -f $FF_DIR/config.jsonc ]]; then
  ok "  custom fastfetch config present — left untouched"
elif [[ ! -f /etc/fastfetch/config.jsonc ]]; then
  warn "  /etc/fastfetch/config.jsonc not found — skipping"
else
  if $DRY_RUN; then
    info "  [dry-run] would seed ~/.config/fastfetch/config.jsonc (system default + Stellarchy line)"
  else
    mkdir -p "$FF_DIR"
    cp /etc/fastfetch/config.jsonc "$FF_DIR/config.jsonc"
    sed -i 's/Omarchy \$version/Stellarchy (Omarchy \$version)/' "$FF_DIR/config.jsonc"
    ok "  seeded ~/.config/fastfetch/config.jsonc (system default + Stellarchy line)"
  fi
  changed=$((changed+1))
fi

echo ""

# ──────────────────────────────────────────────
# Branding (screensaver.txt / about.txt) — Stellarchy wordmark.
# Installs when missing, replaces files still identical to Omarchy's stock
# art, and refreshes older omartia deploys. Genuine user customization is
# never touched.
# ──────────────────────────────────────────────

info "Branding:"
BRANDING_DIR="$HOME/.config/omarchy/branding"
declare -A BRAND_STOCK=(
  ["screensaver.txt"]="/usr/share/omarchy/logo.txt"
  ["about.txt"]="/usr/share/omarchy/icon.txt"
)
for f in screensaver.txt about.txt; do
  src="$REPO_DIR/branding/$f"
  dst="$BRANDING_DIR/$f"
  stock="${BRAND_STOCK[$f]}"
  if [[ ! -f $src ]]; then
    warn "  $f missing from repo — skipping"
    continue
  fi
  mkdir -p "$BRANDING_DIR"
  if [[ ! -f $dst ]]; then
    if ! $DRY_RUN; then cp "$src" "$dst"; fi
    ok "  $f installed"
    changed=$((changed+1))
  elif cmp -s "$dst" "$src"; then
    ok "  $f up to date"
  elif [[ -n $stock && -f $stock ]] && cmp -s "$dst" "$stock"; then
    if $DRY_RUN; then
      info "  [dry-run] would replace stock $f with Stellarchy art"
    else
      cp "$src" "$dst"
    fi
    ok "  $f rebranded (was stock Omarchy art)"
    changed=$((changed+1))
  elif grep -q 'Stellarchy' "$dst"; then
    if $DRY_RUN; then
      info "  [dry-run] would refresh $f to current Stellarchy art"
    else
      cp "$src" "$dst"
    fi
    ok "  $f refreshed (older omartia version)"
    changed=$((changed+1))
  else
    ok "  $f customized — left untouched"
  fi
done
unset BRAND_STOCK

echo ""

# ──────────────────────────────────────────────
# CachyOS BORE kernel — opt-in via --bore. Stock kernel is never removed;
# DEFAULT_ENTRY is name-based so it survives limine.conf regeneration.
# ──────────────────────────────────────────────

setup_chaotic_kernel() {
  rr() { # root runner with dry-run support
    if $DRY_RUN; then info "  [dry-run] would run: sudo $*"; else sudo "$@"; fi
  }

  if pacman -Q linux-cachyos-bore &>/dev/null; then
    ok "  BORE kernel already installed"
  else
    if ! grep -q '^\[chaotic-aur\]' /etc/pacman.conf; then
      info "  adding chaotic-aur repo..."
      rr pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
      rr pacman-key --lsign-key 3056513887B78AEB
      rr bash -c "pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'"
      [[ -f /etc/pacman.conf.omartia-backup ]] || rr cp /etc/pacman.conf /etc/pacman.conf.omartia-backup
      printf '\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist\n' | { $DRY_RUN && info "  [dry-run] would append [chaotic-aur] to /etc/pacman.conf" || sudo tee -a /etc/pacman.conf >/dev/null; }
    else
      ok "  chaotic-aur already configured"
    fi
    rr pacman -Sy --noconfirm
    rr pacman -S --ask 4 --noconfirm linux-cachyos-bore linux-cachyos-bore-headers
  fi

  if grep -q '^DEFAULT_ENTRY=' /etc/limine-entry-tool.conf 2>/dev/null; then
    rr sed -i 's|^DEFAULT_ENTRY=.*|DEFAULT_ENTRY="Omarchy/linux-cachyos-bore"|' /etc/limine-entry-tool.conf
  else
    printf 'DEFAULT_ENTRY="Omarchy/linux-cachyos-bore"\n' | { $DRY_RUN && info "  [dry-run] would set DEFAULT_ENTRY in /etc/limine-entry-tool.conf" || sudo tee -a /etc/limine-entry-tool.conf >/dev/null; }
  fi
  rr limine-update
  ok "  BORE is now the default boot entry (stock kernel kept as fallback)"
}

info "Kernel:"
if $BORE; then
  setup_chaotic_kernel
elif pacman -Q linux-cachyos-bore &>/dev/null; then
  if grep -q '^DEFAULT_ENTRY=' /etc/limine-entry-tool.conf 2>/dev/null; then
    ok "BORE kernel present, default boot entry configured"
  else
    warn "BORE kernel present but stock kernel still auto-boots first"
    warn "  fix with: ./upgrade.sh --bore"
  fi
else
  ok "stock Arch kernel (opt in anytime: ./upgrade.sh --bore)"
fi

echo ""

# ──────────────────────────────────────────────
# Plymouth splash — stellarchy theme. Refreshes assets when already
# active; offers adoption once on systems still on the stock splash.
# ──────────────────────────────────────────────

info "Plymouth splash:"
PLYMOUTH_SRC="$REPO_DIR/branding/plymouth"
PLYMOUTH_DST="/usr/share/plymouth/themes/stellarchy"
OMARCHY_PLY="/usr/share/plymouth/themes/omarchy"

if [[ ! -d $OMARCHY_PLY ]]; then
  warn "  Omarchy plymouth theme not found — skipping"
elif [[ -d $PLYMOUTH_DST ]] || grep -q '^Theme=stellarchy' /etc/plymouth/plymouthd.conf 2>/dev/null; then
  if $DRY_RUN; then
    info "  [dry-run] would refresh stellarchy theme assets"
  else
    NEEDS_INITRD=false
    sudo mkdir -p "$PLYMOUTH_DST"
    for pair in "stellarchy-logo.png:logo.png" "stellarchy.plymouth:stellarchy.plymouth"; do
      src="$PLYMOUTH_SRC/${pair%%:*}"
      dst="$PLYMOUTH_DST/${pair##*:}"
      if [[ ! -f $dst ]] || ! cmp -s "$src" "$dst"; then
        sudo cp "$src" "$dst"
        NEEDS_INITRD=true
      fi
    done
    for f in bullet.png entry.png lock.png progress_bar.png progress_box.png; do
      if [[ -f $OMARCHY_PLY/$f ]] && ! cmp -s "$OMARCHY_PLY/$f" "$PLYMOUTH_DST/$f"; then
        sudo cp "$OMARCHY_PLY/$f" "$PLYMOUTH_DST/$f"
        NEEDS_INITRD=true
      fi
    done
    if ! grep -q '^Theme=stellarchy' /etc/plymouth/plymouthd.conf 2>/dev/null; then
      sudo plymouth-set-default-theme stellarchy
      NEEDS_INITRD=true
    fi
    if [[ ${NEEDS_INITRD:-false} == true ]]; then
      info "  rebuilding initramfs..."
      sudo mkinitcpio -P
      ok "  stellarchy splash refreshed"
    else
      ok "  stellarchy splash up to date"
    fi
  fi
else
  if ! $PLYMOUTH; then
    info "stock splash active — adopt anytime with: ./upgrade.sh --plymouth"
  elif $DRY_RUN; then
    info "  [dry-run] would adopt the stellarchy splash (rebuilds initramfs)"
  else
    NEEDS_INITRD=false
    sudo mkdir -p "$PLYMOUTH_DST"
    for pair in "stellarchy-logo.png:logo.png" "stellarchy.plymouth:stellarchy.plymouth"; do
      src="$PLYMOUTH_SRC/${pair%%:*}"
      dst="$PLYMOUTH_DST/${pair##*:}"
      sudo cp "$src" "$dst"
      NEEDS_INITRD=true
    done
    for f in bullet.png entry.png lock.png progress_bar.png progress_box.png; do
      [[ -f $OMARCHY_PLY/$f ]] && ! cmp -s "$OMARCHY_PLY/$f" "$PLYMOUTH_DST/$f" && { sudo cp "$OMARCHY_PLY/$f" "$PLYMOUTH_DST/$f"; }
    done
    sudo plymouth-set-default-theme stellarchy
    info "  rebuilding initramfs..."
    sudo mkinitcpio -P
    ok "  stellarchy splash adopted"
  fi
fi

echo ""

# ──────────────────────────────────────────────
# Session commands — ensure SDDM-safe logout
# loginctl terminate-user / dispatch exit kill the session in ways that
# make sddm-helper exit non-zero; SDDM then never relaunches (black screen).
# omartia-logout unwinds via uwsm so sddm-helper exits cleanly.
# ──────────────────────────────────────────────

CAELESTIA_SHELL_JSON="$HOME/.config/caelestia/shell.json"
info "Session commands:"

logout_ok() {
  python3 - "$1" <<'EOF'
import json, sys
c = json.load(open(sys.argv[1]))
sys.exit(0 if c.get("session", {}).get("commands", {}).get("logout") == ["omarchy-system-logout"] else 1)
EOF
}

if [[ ! -f $CAELESTIA_SHELL_JSON ]]; then
  warn "  no caelestia/shell.json found — skipping"
elif logout_ok "$CAELESTIA_SHELL_JSON"; then
  ok "  logout command up to date"
elif $DRY_RUN; then
  info "  [dry-run] would set session.commands.logout -> omarchy-system-logout"
  changed=$((changed+1))
else
  cp "$CAELESTIA_SHELL_JSON" "$CAELESTIA_SHELL_JSON.pre-upgrade.bak"
  python3 - "$CAELESTIA_SHELL_JSON" <<'EOF'
import json, sys
p = sys.argv[1]
c = json.load(open(p))
c.setdefault("session", {}).setdefault("commands", {})["logout"] = ["omarchy-system-logout"]
json.dump(c, open(p, "w"), indent=4)
EOF
  ok "  logout command set to omartia-logout (backup: caelestia/shell.json.pre-upgrade.bak)"
  changed=$((changed+1))
fi

echo ""

# ──────────────────────────────────────────────
# Config drift report (read-only — never overwritten)
# ──────────────────────────────────────────────

info "Config drift (repo vs live — informational only):"

check_drift() { # <repo-file> <live-file>
  local repo_f="$1" live_f="$2"
  if [[ ! -f $live_f ]]; then
    warn "  missing: ${live_f/#$HOME/\~}"
  elif cmp -s "$repo_f" "$live_f"; then
    ok "  same: ${live_f/#$HOME/\~}"
  else
    warn "  differs: ${live_f/#$HOME/\~} (your edits kept — review with: diff \"$repo_f\" \"$live_f\")"
  fi
}

while IFS= read -r f; do
  rel="${f#"$REPO_DIR"/config/}"
  check_drift "$f" "$HOME/.config/$rel"
done < <(find "$REPO_DIR/config" -type f | sort)

echo ""

# ──────────────────────────────────────────────
# Summary
# ──────────────────────────────────────────────

if (( changed == 0 )); then
  ok "Everything already up to date."
elif $DRY_RUN; then
  info "$changed item(s) would be synced."
else
  ok "$changed item(s) synced."
  echo -e "${CYAN}[omartia]${NC} If keybinds changed, run: ${YELLOW}hyprctl reload${NC}"
fi
