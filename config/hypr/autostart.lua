-- omartia-dots-remux: Autostart
-- Caelestia Shell runs alongside omarchy-shell (plugins disabled via shell.json)

hl.on("hyprland.start", function()
  -- Systemd / D-Bus environment setup (required for systemctl --user)
  hl.exec_cmd("systemctl --user import-environment $(env | cut -d'=' -f 1)")
  hl.exec_cmd("dbus-update-activation-environment --systemd --all")

  -- Start Caelestia Shell via systemd (auto-restarts on crash or update)
  hl.exec_cmd("systemctl --user start caelestia-shell.service")
end)
