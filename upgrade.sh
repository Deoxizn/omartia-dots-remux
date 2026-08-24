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
KERNEL=""
PLYMOUTH=false

# CachyOS kernel variants installable via chaotic-aur: variant -> base package.
declare -A KERNEL_PKGS=(
  [default]="linux-cachyos"
  [bore]="linux-cachyos-bore"
  [eevdf]="linux-cachyos-eevdf"
  [lts]="linux-cachyos-lts"
  [rt-bore]="linux-cachyos-rt-bore"
)

for arg in "$@"; do
  case "$arg" in
    -n|--dry-run) DRY_RUN=true ;;
    --no-pull) NO_PULL=true ;;
    --adopt-lua) ADOPT_LUA=true ;;
    --kernel)
      # value consumed from the next argv slot below
      KERNEL=__PENDING__ ;;
    --kernel=?*)
      KERNEL=${arg#--kernel=} ;;
    --plymouth) PLYMOUTH=true ;;
    -h|--help)
      echo "Usage: ./upgrade.sh [--dry-run] [--no-pull] [--adopt-lua] [--kernel K] [--plymouth]"
      echo "  --dry-run    show what would change without touching anything"
      echo "  --no-pull    skip git pull (sync from current checkout)"
      echo "  --adopt-lua  adopt repo versions of hypr lua configs that have no"
      echo "               sync history (your current file is backed up first)"
      echo "  --kernel K   opt into a CachyOS kernel via chaotic-aur. K is one of:"
      echo "                 default  linux-cachyos        (EEVDF, their current default)"
      echo "                 bore     linux-cachyos-bore   (gaming/interactivity)"
      echo "                 eevdf    linux-cachyos-eevdf  (explicit EEVDF build)"
      echo "                 lts      linux-cachyos-lts    (long-term support)"
      echo "                 rt-bore  linux-cachyos-rt-bore(real-time + BORE)"
      echo "               Installs the kernel + headers (prebuilt), makes it the"
      echo "               default Limine entry. Stock Arch kernel stays as fallback."
      echo "  --plymouth   adopt the Stellarchy boot splash (rebuilds initramfs)."
      exit 0 ;;
    *)
      if [[ $KERNEL == __PENDING__ ]]; then
        KERNEL=$arg
      else
        printf '\033[0;31m[stellarchy]\033[0m %s\n' "Unknown argument: $arg (see --help)"
        exit 1
      fi ;;
  esac
done

if [[ -n $KERNEL && -z ${KERNEL_PKGS[$KERNEL]:-} ]]; then
  printf '\033[0;31m[stellarchy]\033[0m %s\n' "--kernel: unknown variant '$KERNEL' (valid: ${!KERNEL_PKGS[*]} )"
  exit 1
fi

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${CYAN}[stellarchy]${NC} $*"; }
ok()    { echo -e "${GREEN}[stellarchy]${NC} $*"; }
warn()  { echo -e "${YELLOW}[stellarchy]${NC} $*"; }
err()   { echo -e "${RED}[stellarchy]${NC} $*" >&2; }

rebuild_initrd() {
  if ! mountpoint -q /boot; then
    warn "  /boot is not mounted — refusing to leave boot images half-built."
    warn "  Mount the ESP (e.g. mount /dev/nvme0n1p1 /boot) and rerun: sudo limine-mkinitcpio"
    return 1
  fi
  info "  rebuilding initramfs (limine-mkinitcpio)..."
  if ! sudo limine-mkinitcpio; then
    warn "  limine-mkinitcpio FAILED — UKIs are stale. DO NOT reboot until a rebuild succeeds."
    warn "  Escape hatch: echo -e '[Daemon]\nTheme=omarchy' > /etc/plymouth/plymouthd.conf && sudo limine-mkinitcpio"
    return 1
  fi
}

# The mkinitcpio plymouth hook packs ONLY the active theme's directory.
# A .plymouth whose ScriptFile points at another theme's dir ships an
# initramfs with no boot script: plymouth renders nothing, so the splash
# AND LUKS password prompt are invisible — black screen, boot looks dead.
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
      err "  vendor the script into $dir instead."
      return 1 ;;
  esac
  if [[ ! -f $sf ]]; then
    err "  ScriptFile missing: $sf"
    return 1
  fi
  return 0
}

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
# Pull latest — FIRST, so patches and every sync below act on the newest
# checkout rather than whatever was on disk when the script started.
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
# Caelestia shell patches — re-applied on every upgrade so remux patches
# (e.g. patches/0002 os-release overlay) survive upstream shell updates.
# Kept as uncommitted working-tree changes; already-applied patches are a no-op.
# ──────────────────────────────────────────────

CAELESTIA_DIR="$HOME/.config/quickshell/caelestia"
if [[ -d "$CAELESTIA_DIR/.git" ]]; then
  info "Caelestia shell patches:"
  for p in "$REPO_DIR"/patches/*.patch; do
    [[ -e $p ]] || break
    if git -C "$CAELESTIA_DIR" apply --check "$p" 2>/dev/null; then
      git -C "$CAELESTIA_DIR" apply "$p" \
        && ok "  applied: $(basename "$p")" \
        || warn "  failed to apply: $(basename "$p")"
    elif git -C "$CAELESTIA_DIR" apply --reverse --check "$p" 2>/dev/null; then
      ok "  already applied: $(basename "$p")"
    else
      warn "  no longer fits upstream ($(basename "$p")) — skipping"
    fi
  done
  echo ""
fi

# ──────────────────────────────────────────────
# Menu suite scripts → ~/.local/bin
# ──────────────────────────────────────────────

info "Menu suite scripts:"

shopt -s nullglob
repo_scripts=("$REPO_DIR"/scripts/stellarchy-*)
if (( ${#repo_scripts[@]} == 0 )); then
  warn "  no scripts found in repo"
fi
for src in "${repo_scripts[@]}"; do
  copy_if_changed "$src" "$HOME/.local/bin/$(basename "$src")" "$(basename "$src")"
done
# Scripts removed upstream but still installed locally
for dst in "$HOME/.local/bin/"stellarchy-*; do
  [[ -f "$REPO_DIR/scripts/$(basename "$dst")" ]] || warn "  $(basename "$dst") no longer in repo — left in place, remove manually if unwanted"
done
# Scripts dropped by the menu rework (superseded; safe to delete)
stale_scripts=("$HOME/.local/bin/stellarchy-update-process")
for dst in "${stale_scripts[@]}"; do
  [[ -f $dst ]] || continue
  if $DRY_RUN; then
    info "  [dry-run] would remove stale $(basename "$dst")"
  else
    rm -f "$dst"
    ok "  removed stale $(basename "$dst")"
  fi
done
shopt -u nullglob

# Pre-rename binaries (scripts were omartia-* before the stellarchy rebrand)
shopt -s nullglob
legacy_scripts=("$HOME/.local/bin/"omartia-*)
if (( ${#legacy_scripts[@]} )); then
  if $DRY_RUN; then
    info "  [dry-run] would remove ${#legacy_scripts[@]} legacy omartia-* scripts"
  else
    rm -f "${legacy_scripts[@]}"
    ok "  removed ${#legacy_scripts[@]} legacy omartia-* scripts"
  fi
fi
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
guard_src="$REPO_DIR/hooks/libalpm/stellarchy-guard-restart-shell.sh"
hook_src="$REPO_DIR/hooks/libalpm/stellarchy-restart-shell-guard.hook"
guard_dst="/usr/local/bin/stellarchy-guard-restart-shell.sh"
hook_dst="/usr/share/libalpm/hooks/stellarchy-restart-shell-guard.hook"

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

# ──────────────────────────────────────────────
# Splash guard — re-applies the Stellarchy splash after kernel installs.
# Without it a kernel installed between upgrades builds its UKI from
# whatever theme state existed mid-transaction; the hook detects an adopted
# splash and rebuilds so the new kernel boots with stellarchy.
# ──────────────────────────────────────────────

info "Splash guard:"
ply_refresh_src="$REPO_DIR/hooks/libalpm/stellarchy-plymouth-refresh.sh"
ply_hook_src="$REPO_DIR/hooks/libalpm/stellarchy-plymouth-refresh.hook"
ply_refresh_dst="/usr/local/bin/stellarchy-plymouth-refresh.sh"
ply_hook_dst="/usr/share/libalpm/hooks/95-stellarchy-plymouth-refresh.hook"

if [[ -f $ply_refresh_dst || -f $guard_dst ]]; then
  sync_root_file "$ply_refresh_src" "$ply_refresh_dst" "splash guard script" 755
  sync_root_file "$ply_hook_src" "$ply_hook_dst" "splash libalpm hook" 644
else
  warn "  root hooks not deployed by installer — skipping (run install.sh to add them)"
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
# ERE marking a live file as carrying remux content. Files matching NONE of
# it are stock Omarchy defaults or foreign rewrites — merging into those is
# meaningless, so they are adopted wholesale (with backup) below.
declare -A OWNED_RE=(
  [hyprland.lua]='omartia-dots-remux|package\.loaded\["default\.hypr\.autostart"\]'
  [autostart.lua]='omartia-dots-remux|caelestia-shell'
  [looknfeel.lua]='omartia-dots-remux'
)
BASE_DIR="$HOME/.config/hypr/.stellarchy-base"
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
  elif [[ -n ${OWNED_RE[$name]:-} ]] && ! grep -qE "${OWNED_RE[$name]}" "$dst"; then
    # Live file has none of the remux's content (fresh Omarchy default or a
    # foreign rewrite): adopting wholesale is the only meaningful sync here,
    # and it guarantees the documented dots behavior actually exists.
    if $DRY_RUN; then
      info "  [dry-run] would replace unowned $name with repo version (backup: hypr/$name.pre-upgrade.bak)"
    else
      cp "$dst" "$dst.pre-upgrade.bak"
      install -m644 "$src" "$dst"
      cp -f "$src" "$base"
      ok "  replaced unowned $name with repo version (backup: hypr/$name.pre-upgrade.bak)"
    fi
    changed=$((changed+1))
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
# Files already carrying the managed block get it refreshed in place; a file
# WITHOUT any remux content (stock default or a stale partial install) is
# backed up and replaced wholesale, so the documented keybinding set actually
# exists. Hyprland applies binds top-down with last-wins, so repo keybinds
# always take effect on every machine.
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

  # Strip legacy auto-injected stellarchy blocks (predecessors of the managed
  # block). Duplicates make toggle binds (sidebar/dashboard) fire twice and
  # appear dead. A legacy block = its marker comment plus the command lines
  # after it, up to the next blank line.
  if grep -q -- "-- omartia-dots-remux: .*auto-injected" "$BINDINGS_FILE"; then
    if $DRY_RUN; then
      info "  [dry-run] would remove legacy stellarchy auto-injected binding block(s)"
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
    # No managed block: the file predates the remux's keybinds entirely —
    # stock Omarchy default, or an older installer that only appended a
    # partial auto-injected block (leaving most documented binds missing and
    # the stock omarchy-shell ones dead). Back the whole file up and adopt
    # the repo version wholesale instead of appending beside dead binds.
    if $DRY_RUN; then
      info "  [dry-run] would replace bindings.lua with the managed repo keybind set (backup: hypr/bindings.lua.pre-upgrade.bak)"
      changed=$((changed+1))
    else
      cp "$BINDINGS_FILE" "$BINDINGS_FILE.pre-upgrade.bak"
      install -m644 "$section_file" "$BINDINGS_FILE"
      ok "  replaced bindings.lua with the repo keybind set (backup: hypr/bindings.lua.pre-upgrade.bak)"
      warn "    personal binds from your old file are only in the backup — re-add them above the managed block"
      changed=$((changed+1))
    fi
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

# hypridle drives screensaver/lock/dpms/suspend — stock Omarchy doesn't ship it
# as a dependency, so installs predating install.sh's dep list may lack it.
if ! pacman -Q hypridle &>/dev/null; then
  if $DRY_RUN; then
    info "  [dry-run] would install hypridle"
  else
    warn "  hypridle missing — installing"
    sudo pacman -S --noconfirm --needed hypridle && ok "  hypridle installed"
  fi
fi

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

# Installs predating install.sh's sleep-lock handling still carry stock Omarchy's
# monitor: it calls omarchy-shell IPC that no longer exists here and holds a
# sleep-delay inhibitor — hypridle + caelestia-system-lock own idle/suspend locking.
if systemctl --user is-enabled --quiet omarchy-sleep-lock.service 2>/dev/null; then
  if $DRY_RUN; then
    info "  [dry-run] would disable omarchy-sleep-lock.service"
  else
    systemctl --user disable --now omarchy-sleep-lock.service 2>/dev/null || true
    ok "  omarchy-sleep-lock.service disabled (hypridle owns idle/sleep locking)"
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
    info "  [dry-run] would seed ~/.config/fastfetch/config.jsonc (system default + Stellarchy line + logo)"
  else
    mkdir -p "$FF_DIR"
    cp /etc/fastfetch/config.jsonc "$FF_DIR/config.jsonc"
    cp "$REPO_DIR/stellarchy.png" "$FF_DIR/stellarchy.png"
    sed -i \
      -e 's/Omarchy \$version/Stellarchy (Omarchy \$version)/' \
      -e 's|"type": "file"|"type": "sixel"|' \
      -e 's|"source": "~/.config/omarchy/branding/about.txt"|"source": "~/.config/fastfetch/stellarchy.png",\n    "width": 70,\n    "height": 30|' \
      "$FF_DIR/config.jsonc"
    ok "  seeded ~/.config/fastfetch/config.jsonc (system default + Stellarchy line + logo)"
  fi
  changed=$((changed+1))
fi

echo ""

# ──────────────────────────────────────────────
# Stellarchy identity overlay (~/.config/stellarchy/os-release). Read by the
# Caelestia shell via patches/0002 so lockscreen/About show Stellarchy without
# touching /etc/os-release — fastfetch & omarchy tooling report real info.
# ──────────────────────────────────────────────

info "Stellarchy identity overlay:"
OVERLAY="$HOME/.config/stellarchy/os-release"
LOGO_PATH="$HOME/.config/fastfetch/stellarchy.png"
if [[ -f $OVERLAY ]]; then
  if ! grep -q '^LOGO=' "$OVERLAY"; then
    if $DRY_RUN; then
      info "  [dry-run] would add missing LOGO entry to $OVERLAY"
    else
      printf 'LOGO=%s\n' "$LOGO_PATH" >> "$OVERLAY"
      ok "  added missing LOGO entry to $OVERLAY"
    fi
  else
    ok "  already present — left untouched"
  fi
elif $DRY_RUN; then
  info "  [dry-run] would seed $OVERLAY (NAME/PRETTY_NAME/LOGO → Stellarchy)"
else
  mkdir -p "$HOME/.config/stellarchy"
  {
    printf '# Stellarchy identity overlay — read by the Caelestia shell via patches/0002.\n'
    printf 'NAME="Stellarchy"\n'
    printf 'PRETTY_NAME="Stellarchy"\n'
    printf 'LOGO=%s\n' "$LOGO_PATH"
  } > "$OVERLAY"
  ok "  seeded $OVERLAY"
fi
changed=$((changed+1))

echo ""

# ──────────────────────────────────────────────
# SDDM greeter — refresh the stellarchy theme on drift.
# Vendored identity (logo/metadata/theme.conf) synced from the repo; QML and
# entry art re-mirrored from Omarchy's theme so upstream fixes flow through.
# Current= only flips when still stock omarchy.
# ──────────────────────────────────────────────

if [[ -d /usr/share/sddm/themes/omarchy ]]; then
  info "SDDM greeter:"
  SDDM_SRC="$REPO_DIR/branding/sddm-theme"
  SDDM_DST="/usr/share/sddm/themes/stellarchy"
  SDDM_CONF="/etc/sddm.conf.d/10-theme.conf"
  if $DRY_RUN; then
    info "  [dry-run] would sync $SDDM_DST from repo + mirror Omarchy support art"
  elif sudo mkdir -p "$SDDM_DST" 2>/dev/null; then
    for f in logo.png metadata.desktop theme.conf Main.qml bullet.png entry.png entry-failed.png lock.png lock-failed.png; do
      src="$SDDM_SRC/$f"; dst="$SDDM_DST/$f"
      if [[ -f $src ]] && { [[ ! -f $dst ]] || ! cmp -s "$src" "$dst"; }; then
        sudo cp "$src" "$dst" && ok "  updated: $f"
      elif [[ ! -f $src && -f /usr/share/sddm/themes/omarchy/$f ]] && ! cmp -s "/usr/share/sddm/themes/omarchy/$f" "$dst"; then
        sudo cp "/usr/share/sddm/themes/omarchy/$f" "$dst" && ok "  mirrored: $f"
      fi
    done
    if [[ -f $SDDM_CONF ]] && grep -q '^Current=omarchy' "$SDDM_CONF"; then
      sudo sed -i 's/^Current=.*/Current=stellarchy/' "$SDDM_CONF" && ok "  switched greeter → stellarchy"
    fi
    ok "  stellarchy theme in place"
  else
    warn "  Could not create $SDDM_DST (sudo?) — skipping"
  fi
  echo ""
fi

# ──────────────────────────────────────────────
# Branding (screensaver.txt / about.txt) — Stellarchy wordmark.
# Installs when missing, replaces files still identical to Omarchy's stock
# art, and refreshes older stellarchy deploys. Genuine user customization is
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
    ok "  $f refreshed (older stellarchy version)"
    changed=$((changed+1))
  else
    ok "  $f customized — left untouched"
  fi
done
unset BRAND_STOCK

echo ""

# ──────────────────────────────────────────────
# CachyOS kernel — opt-in via --kernel K. Stock kernel is never
# removed; the default-entry header in /boot/limine.conf is aimed at the chosen
# kernel by live index computation, so it survives kernel add/remove and
# snapshot churn.
# ──────────────────────────────────────────────

setup_chaotic_kernel() {
  local kern="${KERNEL:-bore}"
  local base="${KERNEL_PKGS[$kern]}"
  rr() { # root runner with dry-run support
    if $DRY_RUN; then info "  [dry-run] would run: sudo $*"; else sudo "$@"; fi
  }

  if pacman -Q "$base" &>/dev/null; then
    ok "  $base already installed"
  else
    if ! grep -q '^\[chaotic-aur\]' /etc/pacman.conf; then
      info "  adding chaotic-aur repo..."
      rr pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
      rr pacman-key --lsign-key 3056513887B78AEB
      rr bash -c "pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'"
      [[ -f /etc/pacman.conf.stellarchy-backup ]] || rr cp /etc/pacman.conf /etc/pacman.conf.stellarchy-backup
      printf '\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist\n' | { $DRY_RUN && info "  [dry-run] would append [chaotic-aur] to /etc/pacman.conf" || sudo tee -a /etc/pacman.conf >/dev/null; }
    else
      ok "  chaotic-aur already configured"
    fi
    rr pacman -Sy --noconfirm
    rr pacman -S --ask 4 --noconfirm "$base" "$base-headers"
  fi

  # Regenerate entries first so this kernel's subentry exists in limine.conf
  rr limine-update

  # Aim the static default_entry header at the chosen subentry. Limine
  # accepts an entry path ("OS/kernel") alongside numeric indices — a path
  # keeps pointing at the same kernel through add/remove and snapshot churn,
  # where a computed index silently shifts onto whatever takes the removed
  # entry's place (e.g. the Snapshots submenu). The header survives
  # limine-update; only omarchy-refresh-limine resets it.
  if [[ -f /boot/limine.conf ]]; then
    want="+Omarchy/$base"
    if grep -q "^default_entry:[[:space:]]*$want\$" /boot/limine.conf; then
      ok "  already the default boot entry"
    else
      info "  default boot entry -> $base"
      rr sed -i "s|^default_entry:.*|default_entry: $want|" /boot/limine.conf
    fi
  fi
  ok "  $base ready (stock kernel kept as fallback)"
}

info "Kernel:"
if [[ -n $KERNEL ]]; then
  setup_chaotic_kernel
elif installed_cachyos=$(pacman -Qq 2>/dev/null | grep '^linux-cachyos' | grep -v headers | head -1) && [[ -n $installed_cachyos ]]; then
  want="+Omarchy/$installed_cachyos"
  cur="$(sed -n 's/^default_entry:[[:space:]]*//p' /boot/limine.conf 2>/dev/null || true)"
  if [[ $cur == "$want" ]]; then
    ok "$installed_cachyos present, default boot entry configured"
  elif [[ $cur =~ ^[0-9]+$ ]]; then
    # Stale numeric index from before the path-format switch: kernel
    # add/remove shifts numbered entries onto the wrong target (e.g. the
    # Snapshots submenu) — repoint it at the chosen kernel by name.
    warn "stale numeric default_entry ($cur) — repointing at $installed_cachyos"
    if ! $DRY_RUN; then
      sudo sed -i "s|^default_entry:.*|default_entry: $want|" /boot/limine.conf
    fi
    ok "$installed_cachyos is now the default boot entry"
  else
    warn "$installed_cachyos present but stock kernel still auto-boots first"
    warn "  fix with: ./upgrade.sh --kernel bore"
  fi
else
  ok "stock Arch kernel (opt in anytime: ./upgrade.sh --kernel <${!KERNEL_PKGS[*]}>)"
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
elif grep -q '^Theme=stellarchy' /etc/plymouth/plymouthd.conf 2>/dev/null; then
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
    for f in bullet.png entry.png lock.png progress_bar.png progress_box.png omarchy.script; do
      if [[ -f $OMARCHY_PLY/$f ]] && ! cmp -s "$OMARCHY_PLY/$f" "$PLYMOUTH_DST/$f"; then
        sudo cp "$OMARCHY_PLY/$f" "$PLYMOUTH_DST/$f"
        NEEDS_INITRD=true
      fi
    done
    if ! theme_selfcontained "$PLYMOUTH_DST" stellarchy; then
      err "  stellarchy theme is not self-contained — refusing to rebuild initramfs"
      err "  (a cross-dir ScriptFile ships a splash-less initramfs: black screen)."
      exit 1
    fi
    if ! grep -q '^Theme=stellarchy' /etc/plymouth/plymouthd.conf 2>/dev/null; then
      sudo plymouth-set-default-theme stellarchy
      NEEDS_INITRD=true
    fi
    if [[ ${NEEDS_INITRD:-false} == true ]]; then
      if ! rebuild_initrd; then
        err "  splash refresh incomplete — fix the above before rebooting"
        exit 1
      fi
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
    for f in bullet.png entry.png lock.png progress_bar.png progress_box.png omarchy.script; do
      [[ -f $OMARCHY_PLY/$f ]] && ! cmp -s "$OMARCHY_PLY/$f" "$PLYMOUTH_DST/$f" && { sudo cp "$OMARCHY_PLY/$f" "$PLYMOUTH_DST/$f"; }
    done
    if ! theme_selfcontained "$PLYMOUTH_DST" stellarchy; then
      err "  adoption aborted — stellarchy theme is not self-contained (would boot to a black screen)."
      exit 1
    fi
    sudo plymouth-set-default-theme stellarchy
    if ! rebuild_initrd; then
      err "  adoption failed mid-way — fix the above before rebooting"
      exit 1
    fi
    ok "  stellarchy splash adopted"
  fi
fi

echo ""

# ──────────────────────────────────────────────
# Session commands — ensure SDDM-safe logout
# loginctl terminate-user / dispatch exit kill the session in ways that
# make sddm-helper exit non-zero; SDDM then never relaunches (black screen).
# stellarchy-logout unwinds via uwsm so sddm-helper exits cleanly.
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
  ok "  logout command set to stellarchy-logout (backup: caelestia/shell.json.pre-upgrade.bak)"
  changed=$((changed+1))
fi

# ──────────────────────────────────────────────
# Bar "updates" entry — patch 0003 adds the widget but it only renders when
# listed in bar.entries. Seed the full default list (+ updates) when the user
# has no explicit entries; insert before "clock" if they do.
# ──────────────────────────────────────────────

entries_state() {
  python3 - "$1" <<'EOF'
import json, sys
c = json.load(open(sys.argv[1]))
e = c.get("bar", {}).get("entries")
if e is None:
    print("absent")
elif any(x.get("id") == "updates" for x in e):
    print("present")
else:
    print("missing")
EOF
}

state=$( [[ -f $CAELESTIA_SHELL_JSON ]] && entries_state "$CAELESTIA_SHELL_JSON" || echo absent-file )
info "Bar updates entry:"

case $state in
  absent-file)
    warn "  no caelestia/shell.json found — skipping"
    ;;
  present)
    ok "  updates entry already present"
    ;;
  *)
    if $DRY_RUN; then
      info "  [dry-run] would add 'updates' to bar.entries"
    else
      cp "$CAELESTIA_SHELL_JSON" "$CAELESTIA_SHELL_JSON.pre-upgrade.bak"
      python3 - "$CAELESTIA_SHELL_JSON" <<'EOF'
import json, sys
p = sys.argv[1]
c = json.load(open(p))
bar = c.setdefault("bar", {})
e = bar.get("entries")
if e is None:
    e = [{"enabled": True, "id": i} for i in (
        "logo", "workspaces", "spacer", "activeWindow", "spacer",
        "tray", "updates", "clock", "statusIcons", "power")]
else:
    e.insert(
        next((i for i, x in enumerate(e) if x.get("id") == "clock"), len(e)),
        {"enabled": True, "id": "updates"})
bar["entries"] = e
json.dump(c, open(p, "w"), indent=4)
EOF
      ok "  updates entry added to bar (backup: caelestia/shell.json.pre-upgrade.bak)"
      changed=$((changed+1))
    fi
    ;;
esac

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
  echo -e "${CYAN}[stellarchy]${NC} If keybinds changed, run: ${YELLOW}hyprctl reload${NC}"
fi
