#!/usr/bin/env bash
# ███████╗████████╗███████╗██╗     ██╗      █████╗ ██████╗  ██████╗██╗  ██╗██╗   ██╗
# ██╔════╝╚══██╔══╝██╔════╝██║     ██║     ██╔══██╗██╔══██╗██╔════╝██║  ██║╚██╗ ██╔╝
# ███████╗   ██║   █████╗  ██║     ██║     ███████║██████╔╝██║     ███████║ ╚████╔╝
# ╚════██║   ██║   ██╔══╝  ██║     ██║     ██╔══██║██╔══██╗██║     ██╔══██║  ╚██╔╝
# ███████║   ██║   ███████╗███████╗███████╗██║  ██║██║  ██║╚██████╗██║  ██║   ██║
# ╚══════╝   ╚═╝   ╚══════╝╚══════╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝   ╚═╝

# omartia-dots-remux upgrader — migration tool for existing installs.
# Pulls latest, applies the full config sync (delegates to sync.sh), then
# handles the opt-in system migrations that live here and nowhere else:
#   --kernel K   CachyOS kernel via chaotic-aur + Limine default entry
#   --plymouth   adopt/refresh the Stellarchy boot splash (initramfs rebuild)
# Routine syncing is automatic via omarchy-update; use ./upgrade.sh when you
# want a kernel swap, splash adoption, or a deliberate manual pass.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
DRY_RUN=false
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

SYNC_ARGS=()
for arg in "$@"; do
  case "$arg" in
    -n|--dry-run) DRY_RUN=true; SYNC_ARGS+=(--dry-run) ;;
    --adopt-lua) ADOPT_LUA=true; SYNC_ARGS+=(--adopt-lua) ;;
    --kernel)
      # value consumed from the next argv slot below
      KERNEL=__PENDING__ ;;
    --kernel=?*)
      KERNEL=${arg#--kernel=} ;;
    --plymouth) PLYMOUTH=true ;;
    -h|--help)
      echo "Usage: ./upgrade.sh [--dry-run] [--adopt-lua] [--kernel K] [--plymouth]"
      echo "  --dry-run    show what would change without touching anything"
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

# ──────────────────────────────────────────────
# Preflight
# ──────────────────────────────────────────────

if [[ ! -f "$HOME/.config/caelestia/shell.json" ]]; then
  err "Caelestia config not found — is the remux installed?"
  err "Run ./install.sh first for a fresh install."
  exit 1
fi

# ──────────────────────────────────────────────
# Pull latest — FIRST, so every step below acts on the newest checkout.
# ──────────────────────────────────────────────

branch="$(git -C "$REPO_DIR" symbolic-ref --short HEAD 2>/dev/null || true)"
if [[ -z $branch ]]; then
  warn "Not a git clone — skipping pull"
elif [[ $(git -C "$REPO_DIR" status --porcelain --untracked-files=no | wc -l) -gt 0 ]]; then
  warn "Local uncommitted changes — skipping pull (resolve or stash first)"
else
  info "Pulling latest ($branch)..."
  if git -C "$REPO_DIR" pull --ff-only origin "$branch"; then
    ok "  repo up to date"
  else
    err "  pull failed — continuing from current checkout"
  fi
fi

echo ""

# ──────────────────────────────────────────────
# Full config sync — delegated to sync.sh (the same script the auto-sync
# hook runs after omarchy-update).
# ──────────────────────────────────────────────

info "Config sync (via sync.sh):"
"$REPO_DIR/sync.sh" ${SYNC_ARGS[@]+"${SYNC_ARGS[@]}"}

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
# Summary
# ──────────────────────────────────────────────

ok "Upgrade pass complete."
if [[ -n $KERNEL || $PLYMOUTH == true ]]; then
  echo -e "${CYAN}[stellarchy]${NC} Kernel/splash changes take effect on next reboot."
fi
