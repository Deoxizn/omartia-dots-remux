-- omartia-dots-remux: Keybindings
-- Caelestia launcher replaces omarchy-menu
-- All window management / workspace / app bindings unchanged from omarchy defaults

-- Launcher (replaces omarchy-menu)
hl.unbind("SUPER + SPACE")
hl.unbind("SUPER + ALT + SPACE")
o.bind("SUPER + SPACE", "Caelestia launcher", function() hl.dsp.global("caelestia:launcher") end)
o.bind("SUPER + ALT + SPACE", "Session menu", function() hl.dsp.global("caelestia:session") end)

-- Keybinding help
o.bind("SUPER + K", "Keybindings", "omarchy-menu-keybindings")
o.bind("SUPER + ALT + K", "Tmux keybindings", "omarchy-menu-tmux-keybindings")

-- Screenshot / screen recording
o.bind("PRINT", "Screenshot", "omarchy-capture-screenshot")
o.bind("ALT + PRINT", "Screenrecording", "omarchy-capture-screenrecording")

-- System toggles
o.bind_toggle("SUPER + CTRL + I", "Toggle locking on idle", "idle")
o.bind_toggle("SUPER + CTRL + N", "Toggle nightlight", "nightlight")
o.bind_toggle("SUPER + SHIFT + SPACE", "Toggle top bar", "bar")

-- Notification controls
hl.unbind("SUPER + comma")
hl.unbind("SUPER + SHIFT + comma")
hl.unbind("SUPER + CTRL + comma")
hl.unbind("SUPER + ALT + comma")
hl.unbind("SUPER + SHIFT + ALT + comma")

-- Lock
o.bind("SUPER + CTRL + L", "Lock system", function() hl.dsp.global("caelestia:lock") end)
