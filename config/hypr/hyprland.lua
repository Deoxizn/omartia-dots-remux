-- ──────────────────────────────────────────────
-- Hyprland config — main entry point
-- Caelestia Shell + Omarchy theme bridge
-- ──────────────────────────────────────────────
-- This file wires the whole desktop together. It:
--   1. Loads Omarchy's bootstrap (sets defaults, variables, helpers).
--   2. Stubs out Omarchy's default autostart (Caelestia handles shell launch).
--   3. Loads Omarchy's core (omarchy), then our overrides, then toggles.
--
-- Editing tips:
--   - Add a new category by creating config/hypr/<name>.lua and adding
--     require("hypr.<name>") below (order matters — monitors/input before binds).
--   - Keep the autostart stub AFTER bootstrap.lua: bootstrap clears
--     package.loaded for default.hypr.* on every reload, so a stub before it
--     gets wiped. Replacements for the non-shell parts live in hypr/autostart.lua.
--   - Reload: omarchy-restart-shell or re-login. Check for errors with: hyprctl reload
--
-- File map:
--   hypr/monitors.lua  — display resolution / scale / position
--   hypr/input.lua     — keyboard layout, repeat, pointer
--   hypr/bindings.lua  — keybindings (launcher, media, notifications, etc.)
--   hypr/looknfeel.lua — gaps, rounding, cursor, window rules
--   hypr/autostart.lua — startup apps (Caelestia shell, hooks)

dofile((os.getenv("OMARCHY_PATH") or "/usr/share/omarchy") .. "/default/hypr/bootstrap.lua")  -- Omarchy defaults & helpers (must be first)

-- Caelestia: prevent default omarchy autostart (Caelestia handles shell launch).
-- Must be set AFTER bootstrap.lua: it clears package.loaded for default.hypr.*
-- on every load/reload, so a stub placed before it gets wiped. Replacements for
-- the non-shell parts of the default autostart live in hypr/autostart.lua.
package.loaded["default.hypr.autostart"] = true  -- block Omarchy's shell autostart

require("default.hypr.omarchy")  -- Omarchy core (keybinds, window rules, etc.)

require("hypr.monitors")         -- your monitor layout (outputs, modes, scale)
require("hypr.input")            -- keyboard / pointer config
require("hypr.bindings")         -- Caelestia + Stellarchy key overrides
require("hypr.looknfeel")        -- gaps, rounding, cursor, floating rules
require("hypr.autostart")        -- Caelestia shell & hook launch

require("default.hypr.toggles")  -- Omarchy toggle states (e.g. bar-off)
