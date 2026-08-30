-- ──────────────────────────────────────────────
-- Input device settings
-- Controls keyboard layout, repeat, and pointer behavior.
-- ──────────────────────────────────────────────
-- Edit this for your keyboard / trackpad / mouse.
-- Tips:
--   kb_layout  — "us", "gb", "de", "fr", etc. Multiple: "us,gr" with toggle option.
--   kb_variant — e.g. "intl" for US Intl, "" for default. See `man xkeyboard-config`.
--   kb_options — e.g. "caps:swapescape" (Caps→Esc), "grp:alts_toggle" (Alt+Shift to switch).
--   repeat_rate / repeat_delay — key repeat speed. Higher rate = faster repeat.
--   numlock_by_default — true = NumLock on at login.
-- Validate with: hyprctl devices, wev, or libinput debug.
-- After editing, reload with: omarchy-restart-shell or re-login.

hl.config({
  input = {
    kb_layout = "us",               -- keyboard layout (us, gb, de, etc.). Multiple: "us,ru"
    -- kb_variant = "",              -- layout variant (e.g. "intl", "dvorak"). Uncomment to set.
    -- kb_options = "grp:alts_toggle", -- XKB options (Caps→Ctrl, layout toggle, etc.). See man xkeyboard-config.
    repeat_rate = 40,               -- key repeat rate (keys per second when held)
    repeat_delay = 250,             -- delay before repeat starts (ms)
    numlock_by_default = true,     -- enable NumLock on startup (true/false)
    -- follow_mouse = 1,             -- focus follows mouse (0=off, 1=on, 2=strict). Uncomment to enable.
    -- sensitivity = 0,              -- mouse sensitivity (-1.0 to 1.0). Negative = slower.
    -- accel_profile = "adaptive",   -- mouse accel: "adaptive" or "flat". Uncomment to set.
    -- force_no_accel = false,       -- disable mouse acceleration entirely (true/false).

    touchpad = {                    -- touchpad-specific (uncomment lines to enable)
      -- natural_scroll = true,      -- reverse scroll direction (true = content moves with fingers)
      -- tap_to_click = true,        -- tap to click (true/false)
      -- drag_lock = false,          -- drag lock (true/false)
      -- disable_while_typing = true, -- disable touchpad while typing (true/false)
    },
  },
})
