-- omartia-dots-remux: Hyprland config
-- Caelestia Shell + Omarchy theme bridge

dofile((os.getenv("OMARCHY_PATH") or "/usr/share/omarchy") .. "/default/hypr/bootstrap.lua")

-- Caelestia: prevent default omarchy autostart (Caelestia handles shell launch).
-- Must be set AFTER bootstrap.lua: it clears package.loaded for default.hypr.*
-- on every load/reload, so a stub placed before it gets wiped. Replacements for
-- the non-shell parts of the default autostart live in hypr/autostart.lua.
package.loaded["default.hypr.autostart"] = true

require("default.hypr.omarchy")

require("hypr.monitors")
require("hypr.input")
require("hypr.bindings")
require("hypr.looknfeel")
require("hypr.autostart")

require("default.hypr.toggles")
