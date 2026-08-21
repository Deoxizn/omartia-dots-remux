#!/usr/bin/env bash
# omartia-dots-remux upgrader
# Syncs an existing remux install with the repo: refreshes menu scripts,
# theme bridge hook, update guard, adds any missing menu keybinds, and
# reports config drift (never overwrites your edited configs).
# For fresh installs use install.sh instead.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
DRY_RUN=false
NO_PULL=false

for arg in "$@"; do
  case "$arg" in
    -n|--dry-run) DRY_RUN=true ;;
    --no-pull) NO_PULL=true ;;
    -h|--help)
      echo "Usage: ./upgrade.sh [--dry-run] [--no-pull]"
      echo "  --dry-run   show what would change without touching anything"
      echo "  --no-pull   skip git pull (sync from current checkout)"
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
# Menu keybinds — append only what's missing
# ──────────────────────────────────────────────

BINDINGS_FILE="$HOME/.config/hypr/bindings.lua"
info "Menu keybinds:"

if [[ ! -f $BINDINGS_FILE ]]; then
  warn "  no bindings.lua found — skipping"
else
  bind_lines=()
  grep -q '"omartia-menu"' "$BINDINGS_FILE" 2>/dev/null || {
    bind_lines+=('hl.unbind("SUPER + ALT + SPACE")' 'o.bind("SUPER + ALT + SPACE", "Omartia menu", "omartia-menu")')
  }
  grep -q '"omartia-keybinds"' "$BINDINGS_FILE" 2>/dev/null || {
    bind_lines+=('hl.unbind("SUPER + K")' 'o.bind("SUPER + K", "Keybindings", "omartia-keybinds")')
  }
  grep -q '"omartia-power"' "$BINDINGS_FILE" 2>/dev/null || {
    bind_lines+=('o.bind("SUPER + ESCAPE", "Power menu", "omartia-power")')
  }

  if (( ${#bind_lines[@]} )); then
    if $DRY_RUN; then
      info "  [dry-run] would add ${#bind_lines[@]} binding line(s) to hypr/bindings.lua"
    else
      info "  adding missing menu keybinds..."
      {
        printf '\n-- omartia-dots-remux: menu suite keybinds (auto-injected by upgrade.sh)\n'
        printf '%s\n' "${bind_lines[@]}"
      } >> "$BINDINGS_FILE"
      ok "  hypr/bindings.lua updated — run 'hyprctl reload' to apply"
    fi
    changed=$((changed+1))
  else
    ok "  all menu keybinds present"
  fi
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
