-- omartia-dots-remux: Keybindings
-- Caelestia launcher replaces omarchy-menu
-- All window management / workspace / app bindings unchanged from omarchy defaults

-- Launcher (replaces omarchy-menu)
hl.unbind("SUPER + SPACE")
hl.unbind("SUPER + ALT + SPACE")
o.bind("SUPER + SPACE", "Launcher", { global = "caelestia:launcher" })
o.bind("SUPER + ALT + SPACE", "Session", { global = "caelestia:session" })

-- Notification controls (Caelestia has its own notification service)
hl.unbind("SUPER + comma")
hl.unbind("SUPER + SHIFT + comma")
hl.unbind("SUPER + CTRL + comma")
hl.unbind("SUPER + ALT + comma")
hl.unbind("SUPER + SHIFT + ALT + comma")
o.bind("SUPER + comma", "Dismiss last notification", { global = "caelestia:clearNotifs" })

-- Keybinding help (omarchy-menu-keybindings still works standalone)
o.bind("SUPER + K", "Keybindings", "omarchy-menu-keybindings")
o.bind("SUPER + ALT + K", "Tmux keybindings", "omarchy-menu-tmux-keybindings")

-- Screenshot / screen recording
o.bind("PRINT", "Screenshot", "omarchy-capture-screenshot")
o.bind("ALT + PRINT", "Screenrecording", "omarchy-capture-screenrecording --stop-recording || omarchy-capture-screenshot")

-- Idle / nightlight toggles (IPC targets may differ — test these)
o.bind_toggle("SUPER + CTRL + I", "Toggle locking on idle", "idle")
o.bind_toggle("SUPER + CTRL + N", "Toggle nightlight", "nightlight")

-- Bar visibility (Caelestia bar toggle — test this keybind)
o.bind_toggle("SUPER + SHIFT + SPACE", "Toggle bar", { global = "caelestia:showall" })
