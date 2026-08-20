-- omartia-dots-remux: Keybindings
-- Minimal overrides — only replaces omarchy-menu with Caelestia launcher.
-- Everything else inherits from omarchy defaults (window mgmt, workspaces, apps).
-- Add your own personal bindings below.

-- Caelestia launcher (replaces omarchy-menu)
hl.unbind("SUPER + SPACE")
hl.unbind("SUPER + ALT + SPACE")
o.bind("SUPER + SPACE", "Caelestia launcher", hl.dsp.global("caelestia:launcher"))
o.bind("SUPER + ALT + SPACE", "Session menu", hl.dsp.global("caelestia:session"))

-- Caelestia sidebar / notifications shade
o.bind("SUPER + N", "Notifications shade", hl.dsp.global("caelestia:sidebar"))

-- Caelestia dashboard
o.bind("SUPER + ALT + D", "Dashboard", hl.dsp.global("caelestia:dashboard"))

-- Lock via Caelestia (replaces omarchy-system-lock)
hl.unbind("SUPER + CTRL + L")
o.bind("SUPER + CTRL + L", "Lock system", hl.dsp.global("caelestia:lock"))
