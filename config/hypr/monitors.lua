-- ──────────────────────────────────────────────
-- Monitor configuration
-- Controls which displays are enabled, resolution, position and scale.
-- ──────────────────────────────────────────────
-- List your monitors and supported modes with:
--   hyprctl monitors all
--
-- Common fields for hl.monitor():
--   output   — connector name (e.g. "eDP-1", "DP-1", "HDMI-A-1"). Use "" for
--              fallback/auto (matches whatever is connected). Check hyprctl.
--   mode     — "widthxheight@refresh" (e.g. "1920x1080@60") or "preferred" to
--              pick the monitor's preferred mode. "highres"/"highrr" also work.
--   position — "auto" (let Hyprland place) or "XxY" pixel offset (e.g. "1920x0"
--              places second monitor to the right of a 1920-wide primary).
--   scale    — display scale. Prefer explicit 1 on ≤1200p panels — Hyprland's
--              "auto" DPI-guess often oversizes UI on 1080p laptops. Valid:
--              1, 1.25, 1.5, 2, or "auto". Corner rounding in looknfeel.lua
--              auto-adapts to this value, no need to edit there.
--   transform— rotation (0=normal, 1=90°, 2=180°, 3=270°) or "flipped".
--   vrr      — adaptive sync: 0=off, 1=on, 2=fullscreen only.
--
-- Install note: on first install this file is auto-generated (detected scale).
-- After that edits are yours — reinstalls won't overwrite it.
-- Edit this for your setup after install.

-- Example single monitor:
-- hl.monitor({
--   output = "eDP-1",           -- connector name from hyprctl monitors all
--   mode = "1920x1080@60",      -- resolution@refresh or "preferred"
--   scale = 1,                  -- explicit scale (1 for 1080p, 1.25-2 for HiDPI)
-- })

-- Example dual monitor (left-to-right):
-- hl.monitor({ output = "eDP-1",    mode = "1920x1080@60", scale = 1 })                -- primary (0,0)
-- hl.monitor({ output = "HDMI-A-1", mode = "1920x1080@60", position = "1920x0", scale = 1 })  -- to the right

-- Example auto fallback (works on any single monitor):
-- hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

-- Example disable a monitor:
-- hl.monitor({ output = "HDMI-A-1", mode = "disable" })

-- Example HiDPI 4K monitor:
-- hl.monitor({ output = "DP-1", mode = "3840x2160@60", scale = 1.5 })  -- try 1.5 or 2 for 4K
