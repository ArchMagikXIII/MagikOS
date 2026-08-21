hl.on("hyprland.start", function()
  -- Slow app launch fix -- set systemd vars before starting session services.
  hl.exec_cmd("systemctl --user import-environment $(env | cut -d'=' -f 1)")
  hl.exec_cmd("dbus-update-activation-environment --systemd --all")

  hl.exec_cmd("magikos-launch-shell")
  hl.exec_cmd("magikos-provision-first-run")
  hl.exec_cmd("magikos-powerprofiles-init")
  hl.exec_cmd(o.launch("magikos-hyprland-monitor-watch"))
  hl.exec_cmd(o.launch("udiskie --automount --no-notify --no-tray"))

  -- Run post-boot hooks after startup config has loaded.
  hl.exec_cmd("sleep 2 && magikos-hook post-boot")
end)
