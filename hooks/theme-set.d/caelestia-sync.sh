#!/usr/bin/env bash
# caelestia-sync.sh — Bridge omarchy colors.toml → Caelestia scheme.json
# Installed to: ~/.config/omarchy/hooks/theme-set.d/
# Triggered automatically by omarchy-theme-set after every theme change.
#
# Caelestia Shell watches ~/.local/state/caelestia/scheme.json via FileView
# with watchChanges: true, so it auto-reloads when this script writes a new file.

set -euo pipefail

THEME_DIR="${OMARCHY_CURRENT_THEME:-$HOME/.local/state/omarchy/current/theme}"
SCHEME_DIR="$HOME/.local/state/caelestia"
SCHEME_FILE="$SCHEME_DIR/scheme.json"

if [[ ! -f "$THEME_DIR/colors.toml" ]]; then
  echo "caelestia-sync: no colors.toml found at $THEME_DIR" >&2
  exit 1
fi

mkdir -p "$SCHEME_DIR"

# Extract a color value from colors.toml by key name.
# Returns the hex value without quotes or # prefix. Falls back to a default.
get_color() {
  local key="$1" default="${2:-888888}"
  local val
  val=$(sed -n "s/^${key} *= *\"\(.*\)\"/\1/p" "$THEME_DIR/colors.toml" | head -1)
  if [[ -z "$val" ]]; then
    echo "$default"
  else
    echo "${val#\#}"
  fi
}

# Extract a string value (no stripping)
get_str() {
  local key="$1" default="${2:-}"
  local val
  val=$(sed -n "s/^${key} *= *\"\(.*\)\"/\1/p" "$THEME_DIR/colors.toml" | head -1)
  echo "${val:-$default}"
}

# Get theme name from omarchy's state file, fall back to directory name
THEME_NAME_FILE="$HOME/.local/state/omarchy/current/theme.name"
if [[ -f "$THEME_NAME_FILE" ]]; then
  THEME_NAME=$(cat "$THEME_NAME_FILE")
else
  THEME_NAME=$(basename "$THEME_DIR")
fi

# Read all colors once
accent=$(get_color accent)
background=$(get_color background 111111)
dark_background=$(get_color dark_background 1a1a1a)
darker_background=$(get_color darker_background 0a0a0a)
lighter_background=$(get_color lighter_background 333333)
foreground=$(get_color foreground cccccc)
dark_foreground=$(get_color dark_foreground 444444)
muted=$(get_color muted 666666)
selection=$(get_color selection 222222)
red=$(get_color red ff4444)
yellow=$(get_color yellow aaaa44)
green=$(get_color green 44aa44)
cyan=$(get_color cyan 44aaaa)
blue=$(get_color blue 4444ff)
magenta=$(get_color magenta aa44aa)
bright_red=$(get_color bright_red ff6666)
bright_yellow=$(get_color bright_yellow cccc66)
bright_green=$(get_color bright_green 66cc66)
bright_cyan=$(get_color bright_cyan 66cccc)
bright_blue=$(get_color bright_blue 6666ff)
bright_magenta=$(get_color bright_magenta cc66cc)
bright_foreground=$(get_color bright_foreground eeeeee)
theme_mode=$(get_str mode dark)

cat > "$SCHEME_FILE" << JSONEOF
{
  "name": "$THEME_NAME",
  "mode": "$theme_mode",
  "variant": "tonalspot",
  "colours": {
    "primary": "$accent",
    "onPrimary": "$background",
    "primaryContainer": "$lighter_background",
    "onPrimaryContainer": "$foreground",

    "secondary": "$muted",
    "onSecondary": "$background",
    "secondaryContainer": "$selection",
    "onSecondaryContainer": "$foreground",

    "tertiary": "$blue",
    "onTertiary": "$background",
    "tertiaryContainer": "$dark_foreground",
    "onTertiaryContainer": "$foreground",

    "error": "$red",
    "onError": "$background",
    "errorContainer": "$dark_foreground",
    "onErrorContainer": "$foreground",

    "success": "$green",
    "onSuccess": "$background",
    "successContainer": "$dark_foreground",
    "onSuccessContainer": "$foreground",

    "background": "$background",
    "onBackground": "$foreground",

    "surface": "$background",
    "onSurface": "$foreground",
    "surfaceDim": "$darker_background",
    "surfaceBright": "$lighter_background",
    "surfaceContainerLowest": "$darker_background",
    "surfaceContainerLow": "$background",
    "surfaceContainer": "$dark_background",
    "surfaceContainerHigh": "$lighter_background",
    "surfaceContainerHighest": "$muted",
    "surfaceVariant": "$selection",
    "onSurfaceVariant": "$dark_foreground",

    "inverseSurface": "$foreground",
    "inverseOnSurface": "$background",
    "inversePrimary": "$accent",

    "outline": "$muted",
    "outlineVariant": "$dark_foreground",
    "shadow": "000000",
    "scrim": "000000",

    "primary_paletteKeyColor": "$accent",
    "secondary_paletteKeyColor": "$muted",
    "tertiary_paletteKeyColor": "$blue",
    "neutral_paletteKeyColor": "$background",
    "neutral_variant_paletteKeyColor": "$selection",

    "term0": "$darker_background",
    "term1": "$red",
    "term2": "$green",
    "term3": "$yellow",
    "term4": "$blue",
    "term5": "$magenta",
    "term6": "$cyan",
    "term7": "$foreground",
    "term8": "$dark_foreground",
    "term9": "$bright_red",
    "term10": "$bright_green",
    "term11": "$bright_yellow",
    "term12": "$bright_blue",
    "term13": "$bright_magenta",
    "term14": "$bright_cyan",
    "term15": "$bright_foreground"
  }
}
JSONEOF

echo "caelestia-sync: synced scheme from theme '$THEME_NAME'" >&2
