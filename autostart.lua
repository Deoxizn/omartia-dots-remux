-- omartia-dots-remux: Autostart
-- Caelestia Shell runs alongside omarchy-shell (plugins disabled via shell.json)

hl.on("hyprland.start", function()
  -- Systemd / D-Bus environment setup (required for systemctl --user)
  -- Commands are chained to ensure env is imported BEFORE the service starts
  -- After Caelestia starts, kill the omarchy shell (default autostart launches it)
  hl.exec_cmd("bash -c 'systemctl --user import-environment $(env | cut -d\"=\" -f 1) && dbus-update-activation-environment --systemd --all && systemctl --user start caelestia-shell.service && sleep 3 && pkill -f \"quickshell -n -p .*/omarchy/shell\" 2>/dev/null'")
end)
