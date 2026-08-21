#!/usr/bin/env bash
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

for arg in "$@"; do
  case "$arg" in
    -n|--dry-run) DRY_RUN=true ;;
    --no-pull) NO_PULL=true ;;
    --adopt-lua) ADOPT_LUA=true ;;
    -h|--help)
      echo "Usage: ./upgrade.sh [--dry-run] [--no-pull] [--adopt-lua]"
      echo "  --dry-run    show what would change without touching anything"
      echo "  --no-pull    skip git pull (sync from current checkout)"
      echo "  --adopt-lua  adopt repo versions of hypr lua configs that have no"
      echo "               sync history (your current file is backed up first)"
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
