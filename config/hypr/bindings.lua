-- omartia-dots-remux: Keybindings
-- Minimal overrides — replaces omarchy-menu with the Caelestia launcher and
-- the stellarchy fuzzel menu suite. Everything else inherits from omarchy
-- defaults (window mgmt, workspaces, apps).
-- Add your own personal bindings below.

-- Caelestia launcher (replaces omarchy-menu)
hl.unbind("SUPER + SPACE")
o.bind("SUPER + SPACE", "Caelestia launcher", hl.dsp.global("caelestia:launcher"))

-- Stellarchy menu suite (fuzzel)
o.bind("SUPER + ALT + SPACE", "Stellarchy menu", "stellarchy-menu")

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
o.bind("SUPER + K", "Keybindings", "stellarchy-keybinds")

-- Power menu (fuzzel)
o.bind("SUPER + ESCAPE", "Power menu", "stellarchy-power")

-- ── Sweep: replace Omarchy defaults that call the removed omarchy-shell ──
-- Stock Omarchy routes these keys into `omarchy-shell`, which this remux
-- removes — without this block every one of them is a silent no-op.
-- Replaced with stellarchy-media (universal MPRIS) and Caelestia equivalents.

-- Media keys -> stellarchy-media: targets whichever MPRIS player is currently
-- Playing, falls back to the first player. Works with any app.
hl.unbind("XF86AudioPlay")
hl.unbind("XF86AudioPause")
hl.unbind("XF86AudioNext")
hl.unbind("XF86AudioPrev")
hl.unbind("ALT + XF86AudioPlay")
hl.unbind("ALT + SHIFT + XF86AudioPlay")
o.bind("XF86AudioPlay", "Play/Pause", "stellarchy-media play-pause", { locked = true })
o.bind("XF86AudioPause", "Pause", "stellarchy-media pause", { locked = true })
o.bind("XF86AudioNext", "Next track", "stellarchy-media next", { locked = true })
o.bind("XF86AudioPrev", "Previous track", "stellarchy-media previous", { locked = true })
o.bind("ALT + XF86AudioPlay", "Next track", "stellarchy-media next", { locked = true })
o.bind("ALT + SHIFT + XF86AudioPlay", "Previous track", "stellarchy-media previous", { locked = true })

-- Clipboard & emoji panels -> caelestia CLI
hl.unbind("SUPER + CTRL + V")
o.bind("SUPER + CTRL + V", "Clipboard manager", "caelestia clipboard")
hl.unbind("SUPER + CTRL + E")
o.bind("SUPER + CTRL + E", "Emojis", "caelestia emoji")

-- Notification dismissal -> caelestia notifs IPC. Caelestia has no per-notif
-- dismiss / history / invoke-last IPC, so those Omarchy keys stay unbound.
hl.unbind("SUPER + comma")
o.bind("SUPER + comma", "Clear notifications", "qs -c caelestia ipc call notifs clear")

-- Omarchy control-panel chords -> unbound. This remux isn't stock Omarchy,
-- so old muscle memory isn't a contract: the dashboard has one key
-- (SUPER + ALT + D above) and aliasing every panel chord to it just makes
-- five keys do the same thing.
-- SUPER+CTRL+D display chord intentionally left alone: it commonly hosts an
-- app binding of your own (e.g. Vesktop).
for _, key in ipairs({ "SUPER + CTRL + A", "SUPER + CTRL + B", "SUPER + CTRL + W", "SUPER + CTRL + ALT + D" }) do
    hl.unbind(key)
end
hl.unbind("SUPER + CTRL + P")
o.bind("SUPER + CTRL + P", "Power panel", hl.dsp.global("caelestia:session"))

-- Dead bar-panel chords (omarchy-shell togglePanelAt) — Caelestia's bar has
-- no panel-at-index IPC; unbind entirely so they don't shadow real keys.
for panel = 1, 9 do
    hl.unbind("SUPER + CTRL + code:" .. tostring(panel + 9))
end
