source "${MAGIKOS_INSTALL_HELPERS:-${MAGIKOS_INSTALL:-/usr/share/magikos}/install/helpers}/systemd.sh"
if magikos_has_systemd; then
  systemctl enable bluetooth.service
else
  magikos_skip_systemd "bluetooth.sh: not a systemd system"
fi

# AutoEnable stays at its stock default on purpose. It was set to false here to
# persist the power state, which it never did: BlueZ has no such behaviour, so
# all it bought was Bluetooth coming up off on every boot. magikos-bluetooth-power
# holds the state in the rfkill soft block instead, and leaving AutoEnable alone
# is what lets bluetoothd bring the adapter back up when that block is lifted.
