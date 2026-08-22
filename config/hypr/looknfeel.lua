-- omartia-dots-remux: Look and feel

hl.config({
  general = {
    gaps_in = 2,
    gaps_out = 2,
  },
})

-- BEGIN omartia-dots-remux managed rounding (auto-synced by upgrade.sh)
-- Rounded corners matching Caelestia's panel aesthetic. Hyprland's rounding
-- is a single global value in physical px, so derive it from the highest
-- connected monitor scale (~12 logical px) and recompute on hotplug.
local function apply_rounding()
  local target, max_scale = 12, 1
  local ok, mons = pcall(hl.get_monitors)
  if ok and type(mons) == "table" then
    for _, m in ipairs(mons) do
      if (m.scale or 1) > max_scale then
        max_scale = m.scale
      end
    end
  end
  hl.config({ decoration = { rounding = math.floor(target * max_scale + 0.5) } })
end

apply_rounding()
hl.on("monitor.added", apply_rounding)
hl.on("monitor.removed", apply_rounding)
-- END omartia-dots-remux managed rounding

hl.config({
  scrolling = {
    column_width = 0.5,
  },
})

-- Cursor (edit for your cursor theme)
hl.env("XCURSOR_THEME", "breeze_cursors")
hl.env("XCURSOR_SIZE", "24")

hl.on("hyprland.start", function()
  hl.exec_cmd("gsettings set org.gnome.desktop.interface cursor-theme breeze_cursors")
  hl.exec_cmd("gsettings set org.gnome.desktop.interface cursor-size 24")
end)

-- Floating windows
hl.window_rule({
  match = {
    class = "org.omarchy.bluetui|org.omarchy.impala|org.omarchy.wiremix|org.omarchy.btop|org.omarchy.terminal|org.omarchy.bash|org.gnome.NautilusPreviewer|org.gnome.Evince|com.gabm.satty|Omarchy|About|TUI.float|imv|mpv"
  },
  tag = "+floating-window"
})

hl.window_rule({
  match = {
    class = "xdg-desktop-portal-gtk|sublime_text|DesktopEditors|org.gnome.Nautilus",
    title = "^(Open.*Files?|Open [F|f]older.*|Save.*Files?|Save.*As|Save|All Files|.*wants to [open|save].*|[C|c]hoose.*)"
  },
  tag = "+floating-window"
})

hl.window_rule({
  match = { tag = "floating-window" },
  float = true,
  size = { 1000, 720 },
  center = true
})

hl.window_rule({ match = { class = "org.gnome.Calculator" }, float = true })
