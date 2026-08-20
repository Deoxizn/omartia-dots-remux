-- omartia-dots-remux: Autostart
-- Caelestia Shell replaces omarchy-shell. The default autostart is stubbed out
-- in hyprland.lua, so the non-shell parts it used to launch are replicated here.

hl.on("hyprland.start", function()
  -- Systemd / D-Bus environment setup (required for systemctl --user),
  -- chained so the env is imported BEFORE the service starts
  hl.exec_cmd("bash -c 'systemctl --user import-environment $(env | cut -d\"=\" -f 1) && dbus-update-activation-environment --systemd --all && systemctl --user start caelestia-shell.service'")

  -- Non-shell parts of Omarchy's default autostart
  hl.exec_cmd("omarchy-provision-first-run")
  hl.exec_cmd("omarchy-powerprofiles-init")
  hl.exec_cmd(o.launch("omarchy-hyprland-monitor-watch"))
  hl.exec_cmd(o.launch("udiskie --automount --no-notify --no-tray"))
  hl.exec_cmd("sleep 2 && omarchy-hook post-boot")
end)
