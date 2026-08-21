#!/usr/bin/env bash
# caelestia-sync.sh — Bridge omarchy colors.toml → Caelestia scheme.json (v2)
# Installed to: ~/.config/omarchy/hooks/theme-set.d/
# Triggered automatically by omarchy-theme-set after every theme change.
#
# v2 improvements over v1:
#   - tertiary is derived from the accent (hue +60°) instead of hardcoded blue,
#     so all 27 tertiary-based accents follow the theme
#   - containers are tinted with their colour instead of flat dark_foreground
#   - surfaceTint + all 12 *Fixed roles are written (were missing → stock pink)
#   - syncs the theme's wallpaper into Caelestia's state (opt-out:
#     CAELESTIA_SYNC_NO_WALLPAPER=1) without touching the caelestia CLI
#     (the CLI would regenerate colours from the image and clobber this bridge)
#
# Caelestia Shell watches ~/.local/state/caelestia/scheme.json and
# wallpaper/path.txt via FileView watchChanges, so everything hot-reloads.

set -euo pipefail

THEME_DIR="${OMARCHY_CURRENT_THEME:-$HOME/.local/state/omarchy/current/theme}"
SCHEME_DIR="$HOME/.local/state/caelestia"

if [[ ! -f "$THEME_DIR/colors.toml" ]]; then
  echo "caelestia-sync: no colors.toml found at $THEME_DIR" >&2
  exit 1
fi

mkdir -p "$SCHEME_DIR"

# Theme name from omarchy's state file, fall back to directory name
THEME_NAME_FILE="$HOME/.local/state/omarchy/current/theme.name"
if [[ -f "$THEME_NAME_FILE" ]]; then
  THEME_NAME=$(cat "$THEME_NAME_FILE")
else
  THEME_NAME=$(basename "$THEME_DIR")
fi

export OMARTIA_THEME_DIR="$THEME_DIR"
export OMARTIA_THEME_NAME="$THEME_NAME"
export OMARTIA_STATE_DIR="$SCHEME_DIR"

python3 <<'PYEOF'
import colorsys
import json
import os
import tomllib
from pathlib import Path

theme_dir = Path(os.environ["OMARTIA_THEME_DIR"])
theme_name = os.environ["OMARTIA_THEME_NAME"]
state = Path(os.environ["OMARTIA_STATE_DIR"])
mode = "dark"

data = tomllib.loads((theme_dir / "colors.toml").read_text())
mode = data.get("mode", "dark")


def hex2rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def rgb2hex(rgb):
    return "%02x%02x%02x" % tuple(max(0, min(255, round(c))) for c in rgb)


def mix(a, b, t):
    return tuple(a[i] * (1 - t) + b[i] * t for i in range(3))


def get(key, default):
    v = data.get(key)
    if isinstance(v, str) and len(v) >= 7:
        return hex2rgb(v)
    return hex2rgb(default)


accent = get("accent", "888888")
background = get("background", "111111")
dark_background = get("dark_background", "1a1a1a")
darker_background = get("darker_background", "0a0a0a")
lighter_background = get("lighter_background", "333333")
foreground = get("foreground", "cccccc")
dark_foreground = get("dark_foreground", "444444")
muted = get("muted", "666666")
selection = get("selection", "222222")
red = get("red", "ff4444")
yellow = get("yellow", "aaaa44")
green = get("green", "44aa44")
cyan = get("cyan", "44aaaa")
blue = get("blue", "4444ff")
magenta = get("magenta", "aa44aa")
bright_red = get("bright_red", "ff6666")
bright_yellow = get("bright_yellow", "cccc66")
bright_green = get("bright_green", "66cc66")
bright_cyan = get("bright_cyan", "66cccc")
bright_blue = get("bright_blue", "6666ff")
bright_magenta = get("bright_magenta", "cc66cc")
bright_foreground = get("bright_foreground", "eeeeee")

WHITE = (255.0, 255.0, 255.0)
BLACK = (0.0, 0.0, 0.0)


def derive_tertiary(base):
    """Rotate accent hue +60° so tertiary shifts with every theme."""
    h, l, s = colorsys.rgb_to_hls(*(c / 255 for c in base))
    h = (h + 60 / 360) % 1.0
    s = min(0.60, max(0.25, s))
    if mode == "dark":
        l = min(0.75, max(0.45, l))
    else:
        l = min(0.55, max(0.35, l))
    return tuple(c * 255 for c in colorsys.hls_to_rgb(h, l, s))


tertiary = derive_tertiary(accent)


def fixed_roles(base):
    """M3 'fixed' roles: mode-independent pastel container set."""
    return {
        "Fixed": mix(base, WHITE, 0.55),
        "FixedDim": mix(base, WHITE, 0.35),
        "onFixed": mix(base, BLACK, 0.70),
        "onFixedVariant": mix(base, BLACK, 0.45),
    }


pfx = fixed_roles(accent)
sfx = fixed_roles(muted)
tfx = fixed_roles(tertiary)

colours = {
    "primary": rgb2hex(accent),
    "onPrimary": rgb2hex(background),
    "primaryContainer": rgb2hex(mix(lighter_background, accent, 0.18)),
    "onPrimaryContainer": rgb2hex(foreground),
    **{f"primary{k}": rgb2hex(v) for k, v in pfx.items()},

    "secondary": rgb2hex(muted),
    "onSecondary": rgb2hex(background),
    "secondaryContainer": rgb2hex(mix(selection, muted, 0.25)),
    "onSecondaryContainer": rgb2hex(foreground),
    **{f"secondary{k}": rgb2hex(v) for k, v in sfx.items()},

    "tertiary": rgb2hex(tertiary),
    "onTertiary": rgb2hex(background),
    "tertiaryContainer": rgb2hex(mix(darker_background, tertiary, 0.28)),
    "onTertiaryContainer": rgb2hex(foreground),
    **{f"tertiary{k}": rgb2hex(v) for k, v in tfx.items()},

    "error": rgb2hex(red),
    "onError": rgb2hex(background),
    "errorContainer": rgb2hex(mix(darker_background, red, 0.30)),
    "onErrorContainer": rgb2hex(foreground),

    "success": rgb2hex(green),
    "onSuccess": rgb2hex(background),
    "successContainer": rgb2hex(mix(darker_background, green, 0.30)),
    "onSuccessContainer": rgb2hex(foreground),

    "background": rgb2hex(background),
    "onBackground": rgb2hex(foreground),

    "surface": rgb2hex(background),
    "onSurface": rgb2hex(foreground),
    "surfaceDim": rgb2hex(darker_background),
    "surfaceBright": rgb2hex(lighter_background),
    "surfaceTint": rgb2hex(accent),
    "surfaceContainerLowest": rgb2hex(darker_background),
    "surfaceContainerLow": rgb2hex(background),
    "surfaceContainer": rgb2hex(dark_background),
    "surfaceContainerHigh": rgb2hex(lighter_background),
    "surfaceContainerHighest": rgb2hex(muted),
    "surfaceVariant": rgb2hex(selection),
    "onSurfaceVariant": rgb2hex(dark_foreground),

    "inverseSurface": rgb2hex(foreground),
    "inverseOnSurface": rgb2hex(background),
    "inversePrimary": rgb2hex(accent),

    "outline": rgb2hex(muted),
    "outlineVariant": rgb2hex(dark_foreground),
    "shadow": "000000",
    "scrim": "000000",

    "primary_paletteKeyColor": rgb2hex(accent),
    "secondary_paletteKeyColor": rgb2hex(muted),
    "tertiary_paletteKeyColor": rgb2hex(tertiary),
    "neutral_paletteKeyColor": rgb2hex(background),
    "neutral_variant_paletteKeyColor": rgb2hex(selection),

    "term0": rgb2hex(darker_background),
    "term1": rgb2hex(red),
    "term2": rgb2hex(green),
    "term3": rgb2hex(yellow),
    "term4": rgb2hex(blue),
    "term5": rgb2hex(magenta),
    "term6": rgb2hex(cyan),
    "term7": rgb2hex(foreground),
    "term8": rgb2hex(dark_foreground),
    "term9": rgb2hex(bright_red),
    "term10": rgb2hex(bright_green),
    "term11": rgb2hex(bright_yellow),
    "term12": rgb2hex(bright_blue),
    "term13": rgb2hex(bright_magenta),
    "term14": rgb2hex(bright_cyan),
    "term15": rgb2hex(bright_foreground),
}

# --- wallpaper sync -------------------------------------------------------
# Write Caelestia's wallpaper state directly; do NOT use `caelestia wallpaper`,
# it regenerates colours from the image and would clobber this bridge.
if os.environ.get("CAELESTIA_SYNC_NO_WALLPAPER") != "1":
    wp_dir = theme_dir / "backgrounds"
    if wp_dir.is_dir():
        imgs = sorted(
            p for p in wp_dir.iterdir()
            if p.is_file() and p.suffix.lower() in {".jpg", ".jpeg", ".png", ".webp"}
        )
        pick = next(
            (p for p in imgs if theme_name.lower() in p.name.lower()),
            imgs[0] if imgs else None,
        )
        if pick:
            wdir = state / "wallpaper"
            wdir.mkdir(parents=True, exist_ok=True)
            target = pick.resolve()
            (wdir / "path.txt").write_text(str(target) + "\n")
            cur = wdir / "current"
            if cur.is_symlink() or cur.exists():
                cur.unlink()
            cur.symlink_to(target)

scheme = {
    "name": theme_name,
    # Colours.load() reads `flavour` unconditionally; omitting it makes the
    # assignment throw and aborts the whole colour update.
    "flavour": "omarchy",
    "mode": mode,
    "variant": "tonalspot",
    "colours": colours,
}
(state / "scheme.json").write_text(json.dumps(scheme, indent=2) + "\n")
PYEOF

echo "caelestia-sync: synced scheme from theme '$THEME_NAME'" >&2
