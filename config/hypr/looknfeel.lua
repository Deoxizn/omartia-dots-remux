-- omartia-dots-remux: Look and feel

hl.config({
  general = {
    gaps_in = 2,
    gaps_out = 2,
  },
})

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
