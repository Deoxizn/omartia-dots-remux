-- omartia-dots-remux: Keybindings
-- Minimal overrides — replaces omarchy-menu with the Caelestia launcher and
-- the omartia fuzzel menu suite. Everything else inherits from omarchy
-- defaults (window mgmt, workspaces, apps).
-- Add your own personal bindings below.

-- Caelestia launcher (replaces omarchy-menu)
hl.unbind("SUPER + SPACE")
o.bind("SUPER + SPACE", "Caelestia launcher", hl.dsp.global("caelestia:launcher"))

-- Omartia menu suite (fuzzel)
o.bind("SUPER + ALT + SPACE", "Omartia menu", "omartia-menu")

-- Caelestia sidebar / notifications shade
o.bind("SUPER + N", "Notifications shade", hl.dsp.global("caelestia:sidebar"))

-- Caelestia dashboard
o.bind("SUPER + ALT + D", "Dashboard", hl.dsp.global("caelestia:dashboard"))

-- Lock via Caelestia (replaces omarchy-system-lock). Uses the full
-- caelestia-system-lock script, not the bare caelestia:lock IPC — the bare IPC
-- never turns the monitors off after locking.
hl.unbind("SUPER + CTRL + L")
o.bind("SUPER + CTRL + L", "Lock system", "caelestia-system-lock")

-- Keybinding list (fuzzel; omarchy's summons the removed omarchy-shell)
hl.unbind("SUPER + K")
o.bind("SUPER + K", "Keybindings", "omartia-keybinds")

-- Power menu (fuzzel)
o.bind("SUPER + ESCAPE", "Power menu", "omartia-power")
