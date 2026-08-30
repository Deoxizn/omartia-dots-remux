-- ──────────────────────────────────────────────
-- Keybindings — personal overrides
-- Minimal overrides — replaces omarchy-menu with the Caelestia launcher and
-- the stellarchy fuzzel menu suite. Everything else inherits from Omarchy
-- defaults (window mgmt, workspaces, apps).
-- ──────────────────────────────────────────────
-- How to add your own:
--   o.bind("SUPER + X", "Description", "command")              -- simple exec
--   hl.bind("XF86AudioPlay", action, { locked = true })        -- Hyprland dispatcher
--   hl.unbind("SUPER + SPACE")                                  -- remove a stock bind
-- Flags: { locked = true } lets bind work on lockscreen, { mod = "SUPER" } for mods.
-- Format: "SUPER + SHIFT + K", "CTRL + ALT + T", "XF86AudioPlay", etc.
-- After editing, reload with: omarchy-restart-shell or re-login.
-- Find bind list: `hyprctl binds` or `omarchy-keybindings`.
-- Add your own personal bindings at the bottom of this file.

-- ──────────────────────────────────────────────
-- Launcher & menus — replaces Omarchy's omarchy-menu
-- ──────────────────────────────────────────────

-- Caelestia launcher (replaces omarchy-menu) — app & wallpapers & actions
hl.unbind("SUPER + SPACE")                                              -- remove Omarchy's launcher
o.bind("SUPER + SPACE", "Caelestia launcher", hl.dsp.global("caelestia:launcher"))  -- Caelestia's launcher

-- Stellarchy menu suite (fuzzel) — root menu with System/Theme/etc.
o.bind("SUPER + ALT + SPACE", "Stellarchy menu", "stellarchy-menu")    -- fuzzel root menu

-- Caelestia sidebar / notifications shade — notification history & quick toggles
o.bind("SUPER + N", "Notifications shade", hl.dsp.global("caelestia:sidebar"))  -- right shade

-- Caelestia dashboard — overview with weather, media, performance
o.bind("SUPER + ALT + D", "Dashboard", hl.dsp.global("caelestia:dashboard"))  -- dashboard overlay

-- Lock via Caelestia (replaces omarchy-system-lock). Uses the full
-- caelestia-system-lock script, not the bare caelestia:lock IPC — the bare IPC
-- never turns the monitors off after locking.
hl.unbind("SUPER + CTRL + L")                                           -- remove Omarchy lock
o.bind("SUPER + CTRL + L", "Lock system", "caelestia-system-lock")      -- Caelestia lock + dpms off

-- Keybinding list (fuzzel; omarchy's summons the removed omarchy-shell)
hl.unbind("SUPER + K")                                                  -- remove Omarchy's shell-based list
o.bind("SUPER + K", "Keybindings", "stellarchy-keybinds")               -- fuzzel keybind reference

-- Power menu (fuzzel) — shutdown / reboot / logout
o.bind("SUPER + ESCAPE", "Power menu", "stellarchy-power")              -- power / session menu

-- ──────────────────────────────────────────────
-- Sweep: replace Omarchy defaults that call the removed omarchy-shell
-- Stock Omarchy routes these keys into `omarchy-shell`, which this remux
-- removes — without this block every one of them is a silent no-op.
-- Replaced with stellarchy-media (universal MPRIS) and Caelestia equivalents.
-- ──────────────────────────────────────────────

-- Media keys -> stellarchy-media: targets whichever MPRIS player is currently
-- Playing, falls back to the first player. Works with any app. Edit or remove
-- these if you prefer per-app MPRIS controls.
hl.unbind("XF86AudioPlay")                                              -- unbind Omarchy's shell-routed play
hl.unbind("XF86AudioPause")                                             -- unbind Omarchy's shell-routed pause
hl.unbind("XF86AudioNext")                                              -- unbind Omarchy's shell-routed next
hl.unbind("XF86AudioPrev")                                              -- unbind Omarchy's shell-routed prev
hl.unbind("ALT + XF86AudioPlay")                                        -- unbind alt variant
hl.unbind("ALT + SHIFT + XF86AudioPlay")                                -- unbind alt+shift variant
o.bind("XF86AudioPlay", "Play/Pause", "stellarchy-media play-pause", { locked = true })        -- toggle play/pause (any player)
o.bind("XF86AudioPause", "Pause", "stellarchy-media pause", { locked = true })                 -- pause (any player)
o.bind("XF86AudioNext", "Next track", "stellarchy-media next", { locked = true })              -- next track
o.bind("XF86AudioPrev", "Previous track", "stellarchy-media previous", { locked = true })      -- previous track
o.bind("ALT + XF86AudioPlay", "Next track", "stellarchy-media next", { locked = true })        -- alt variant -> next
o.bind("ALT + SHIFT + XF86AudioPlay", "Previous track", "stellarchy-media previous", { locked = true })  -- alt+shift -> prev

-- Clipboard & emoji panels -> caelestia CLI (replaces Omarchy shell panels)
hl.unbind("SUPER + CTRL + V")                                           -- remove Omarchy clipboard panel
o.bind("SUPER + CTRL + V", "Clipboard manager", "caelestia clipboard")  -- Caelestia clipboard history
hl.unbind("SUPER + CTRL + E")                                           -- remove Omarchy emoji panel
o.bind("SUPER + CTRL + E", "Emojis", "caelestia emoji")                 -- Caelestia emoji picker

-- Notification dismissal -> caelestia notifs IPC. Caelestia has no per-notif
-- dismiss / history / invoke-last IPC, so those Omarchy keys stay unbound.
hl.unbind("SUPER + comma")                                              -- remove Omarchy notif clear (shell-based)
o.bind("SUPER + comma", "Clear notifications", "qs -c caelestia ipc call notifs clear")  -- clear all toasts/notifs

-- Omarchy control-panel chords -> unbound. This remux isn't stock Omarchy,
-- so old muscle memory isn't a contract: the dashboard has one key
-- (SUPER + ALT + D above) and aliasing every panel chord to it just makes
-- five keys do the same thing.
-- SUPER+CTRL+D display chord intentionally left alone: it commonly hosts an
-- app binding of your own (e.g. Vesktop).
for _, key in ipairs({ "SUPER + CTRL + A", "SUPER + CTRL + B", "SUPER + CTRL + W", "SUPER + CTRL + ALT + D" }) do
    hl.unbind(key)                                                      -- unbind stock panel chord
end
hl.unbind("SUPER + CTRL + P")                                           -- unbind stock power panel chord
o.bind("SUPER + CTRL + P", "Power panel", hl.dsp.global("caelestia:session"))  -- Caelestia session/power panel

-- Dead bar-panel chords (omarchy-shell togglePanelAt) — Caelestia's bar has
-- no panel-at-index IPC; unbind entirely so they don't shadow real keys.
for panel = 1, 9 do
    hl.unbind("SUPER + CTRL + code:" .. tostring(panel + 9))           -- unbind bar panel index chord
end

-- ──────────────────────────────────────────────
-- Your custom bindings — add below
-- Example:
--   o.bind("SUPER + RETURN", "Terminal", "xdg-terminal-exec")
--   o.bind("SUPER + B", "Browser", "xdg-open https://google.com")
-- ──────────────────────────────────────────────
