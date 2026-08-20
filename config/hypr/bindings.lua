-- omartia-dots-remux: Keybindings
-- Caelestia launcher replaces omarchy-menu
-- All other bindings from original user config preserved

-- ── Unbind defaults we replace ──────────────────
hl.unbind("SUPER + SPACE")
hl.unbind("SUPER + ALT + SPACE")
hl.unbind("SUPER + W")
hl.unbind("SUPER + SHIFT + W")
hl.unbind("SUPER + SHIFT + M")
hl.unbind("SUPER + P")
hl.unbind("SUPER + A")
hl.unbind("SUPER + RETURN")
hl.unbind("SUPER + SHIFT + RETURN")
hl.unbind("SUPER + SHIFT + F")
hl.unbind("SUPER + ALT + SHIFT + F")
hl.unbind("SUPER + SHIFT + B")
hl.unbind("SUPER + SHIFT + ALT + B")
hl.unbind("SUPER + SHIFT + N")
hl.unbind("SUPER + CTRL + D")
hl.unbind("SUPER + ALT + RETURN")

-- ── Caelestia launcher (replaces omarchy-menu) ─
o.bind("SUPER + SPACE", "Caelestia launcher", function() hl.dsp.global("caelestia:launcher") end)
o.bind("SUPER + ALT + SPACE", "Session menu", function() hl.dsp.global("caelestia:session") end)

-- ── Application bindings ────────────────────────
o.bind("SUPER + RETURN", "Terminal (split if focused)", "/home/deoxizn/.config/hypr/scripts/terminal-smart.sh")
o.bind("SUPER + SHIFT + RETURN", "Browser", { omarchy = "browser" })
o.bind("SUPER + SHIFT + F", "File manager", { omarchy = "nautilus" })
o.bind("SUPER + ALT + SHIFT + F", "File manager (cwd)", { omarchy = "nautilus-cwd" })
o.bind("SUPER + SHIFT + B", "Browser", { omarchy = "browser" })
o.bind("SUPER + SHIFT + ALT + B", "Browser (private)", "omarchy-launch-browser --private")
o.bind("SUPER + SHIFT + N", "Editor", { omarchy = "editor" })
o.bind("SUPER + CTRL + D", "Vesktop", "vesktop")
o.bind("SUPER + CTRL + M", "Messenger", { webapp = "https://www.messenger.com" })
o.bind("SUPER + ALT + RETURN", "Tmux", { omarchy = "terminal-tmux" })
o.bind("SUPER + SHIFT + M", "Spotify", { omarchy = "spotify" })

-- ── Custom media / F-key bindings ───────────────
o.bind("XF86Tools", "Fastfetch", "kitty --app-id=org.omarchy.ff fish -c 'ff; exec fish'")
o.bind("XF86Launch5", nil, { webapp = "https://gemini.google.com/app" })
o.bind("XF86Launch6", nil, { webapp = "https://photopea.com" })
o.bind("XF86Launch7", nil, { webapp = "https://learn.omacom.io/2/the-omarchy-manual" })

-- ── Keybinding help ─────────────────────────────
o.bind("SUPER + K", "Keybindings", "omarchy-menu-keybindings")
o.bind("SUPER + ALT + K", "Tmux keybindings", "omarchy-menu-tmux-keybindings")

-- ── Screenshot / screen recording ───────────────
o.bind("PRINT", "Screenshot", "omarchy-capture-screenshot")
o.bind("ALT + PRINT", "Screenrecording", "omarchy-capture-screenrecording")

-- ── System toggles ──────────────────────────────
o.bind_toggle("SUPER + CTRL + I", "Toggle locking on idle", "idle")
o.bind_toggle("SUPER + CTRL + N", "Toggle nightlight", "nightlight")
o.bind_toggle("SUPER + SHIFT + SPACE", "Toggle top bar", "bar")

-- ── Lock ────────────────────────────────────────
o.bind("SUPER + CTRL + L", "Lock system", function() hl.dsp.global("caelestia:lock") end)

-- ── Close ───────────────────────────────────────
o.bind("SUPER + Q", "Close window", hl.dsp.window.close())
