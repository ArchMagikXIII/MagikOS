# Enable services only. Installs are followed by reboot, so don't start/reload
# daemons mid-install. UFW and hardware-gated services stay in their own scripts.
#
# Each unit is enabled only when the package that ships it is actually
# installed. The MagikOS base set is a single list shared by the Arch ISO and
# the Debian port, and a distribution that does not carry one of these (sddm,
# avahi, systemd-oomd) would otherwise fail the enable and abort every later
# leaf under run_logged's errexit.
#
# Supports systemd, OpenRC, and runit via magikos_service_* helpers.
source "${MAGIKOS_INSTALL_HELPERS:-${MAGIKOS_INSTALL:-/usr/share/magikos}/install/helpers}/systemd.sh"

# Map systemd unit names to OpenRC/runit service names where they differ
service_name() {
  local unit="$1"
  case "$unit" in
    *.service) echo "${unit%.service}" ;;
    *) echo "$unit" ;;
  esac
}

enable_unit() {
  local unit="$1"
  local sname
  sname=$(service_name "$unit")

  if magikos_has_systemd; then
    if systemctl list-unit-files "$unit" --no-legend 2>/dev/null | grep -q .; then
      systemctl enable "$unit"
    else
      echo "$unit not installed; skipping"
    fi
  elif magikos_has_openrc; then
    if [[ -f "/etc/init.d/$sname" ]]; then
      rc-update add "$sname" default 2>/dev/null || true
    else
      echo "$sname not installed; skipping"
    fi
  elif magikos_has_runit; then
    if [[ -d "/etc/sv/$sname" ]]; then
      mkdir -p /etc/service
      ln -sf "/etc/sv/$sname" "/etc/service/$sname"
    else
      echo "$sname not installed; skipping"
    fi
  else
    echo "No init system found; cannot enable $unit"
  fi
}

enable_unit avahi-daemon.service
enable_unit systemd-resolved.service
enable_unit NetworkManager.service
# Don't let network-online.target hold up
# graphical.target waiting for DHCP/Wi-Fi association. Nothing in the session
# needs to block on the network. Mirrors the systemd-networkd-wait-online mask
# in install/hardware/network.sh.
magikos_service_mask NetworkManager-wait-online.service
enable_unit power-profiles-daemon.service
# Only SDDM may own the display-manager.service alias. A second enabled DM
# (gdm/lightdm/lxdm/greetd/ly, whether left over from the live media or a prior
# install) would boot a second, generic greeter alongside the SDDM one. Disable
# the known alternatives first so the alias points at SDDM and no competitor
# starts. Absent units are harmless; we don't start/reload anything since
# installs are followed by reboot.
for dm in gdm lightdm lxdm greetd ly sddm; do
  magikos_service_disable "$dm.service"
done
rm -f /etc/systemd/system/display-manager.service
enable_unit sddm.service
# Kill one runaway app scope instead of letting reclaim thrashing take the
# whole session down. [Install] pulls in systemd-oomd.socket via Also=, which
# is what the user manager reports app.slice candidacy over.
enable_unit systemd-oomd.service