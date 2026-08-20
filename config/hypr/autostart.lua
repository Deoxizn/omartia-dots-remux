-- omartia-dots-remux: Autostart
-- Caelestia Shell replaces omarchy-shell

hl.on("hyprland.start", function()
  -- Systemd / D-Bus environment setup
  hl.exec_cmd("systemctl --user import-environment $(env | cut -d'=' -f 1)")
  hl.exec_cmd("dbus-update-activation-environment --systemd --all")

  -- Caelestia Shell (replaces omarchy-launch-shell)
  hl.exec_cmd("caelestia shell -d")

  -- Omarchy services
  hl.exec_cmd("omarchy-provision-first-run")
  hl.exec_cmd("omarchy-powerprofiles-init")
  hl.exec_cmd(o.launch("omarchy-hyprland-monitor-watch"))
  hl.exec_cmd(o.launch("udiskie --automount --no-notify --no-tray"))

  -- Post-boot hooks
  hl.exec_cmd("sleep 2 && omarchy-hook post-boot")
end)
