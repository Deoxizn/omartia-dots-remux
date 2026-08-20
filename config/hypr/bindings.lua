-- omartia-dots-remux: Keybindings
-- Minimal overrides — only replaces omarchy-menu with Caelestia launcher.
-- Everything else inherits from omarchy defaults (window mgmt, workspaces, apps).
-- Add your own personal bindings below.

-- Caelestia launcher (replaces omarchy-menu)
hl.unbind("SUPER + SPACE")
hl.unbind("SUPER + ALT + SPACE")
o.bind("SUPER + SPACE", "Caelestia launcher", function() hl.dsp.global("caelestia:launcher") end)
o.bind("SUPER + ALT + SPACE", "Session menu", function() hl.dsp.global("caelestia:session") end)

-- Lock via Caelestia (replaces omarchy-system-lock)
hl.unbind("SUPER + CTRL + L")
o.bind("SUPER + CTRL + L", "Lock system", function() hl.dsp.global("caelestia:lock") end)
