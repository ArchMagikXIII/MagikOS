# Enable services only. Installs are followed by reboot, so don't start/reload
# daemons mid-install. UFW and hardware-gated services stay in their own scripts.
#
# Optional units are enabled only when their package ships a service. The
# MagikOS base set is shared by the Arch ISO and the Debian port, so missing
# optional services must not abort later setup. On OpenRC, dbus and elogind
# are required because their -openrc packages are part of the Artix base.
#
# Supports systemd, OpenRC, and runit via magikos_service_* helpers.
source "${MAGIKOS_INSTALL_HELPERS:-${MAGIKOS_INSTALL:-/usr/share/magikos/install}/helpers}/systemd.sh"

# Runit service names just drop the systemd suffix; OpenRC also needs the
# Artix-specific bluetoothd translation, handled by the init helper.
service_name() {
  local unit="$1"
  case "$unit" in
    *.service) echo "${unit%.service}" ;;
    *) echo "$unit" ;;
  esac
}

enable_unit() {
  local unit="$1" sname
  sname=$(service_name "$unit")

  if magikos_has_systemd; then
    if systemctl list-unit-files "$unit" --no-legend 2>/dev/null | grep -q .; then
      systemctl enable "$unit"
    else
      echo "$unit not installed; skipping"
    fi
  elif magikos_has_openrc; then
    sname=$(magikos_openrc_service_name "$unit")
    if magikos_openrc_has_service "$sname"; then
      # A broken rc-update is an install error, including for the optional
      # NetworkManager and sddm packages once their init scripts exist.
      magikos_service_enable "$unit"
    elif [[ ${2:-} == required ]]; then
      echo "$sname init script missing; install its OpenRC package" >&2
      return 1
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

# The Artix base set already includes dbus-openrc and elogind-openrc. Ensure
# their init scripts are present and linked into default and boot respectively.
# Do not try to enable systemd-only resolved/oomd or wait-online on OpenRC.
if [[ $(magikos_detect_init) == openrc ]]; then
  enable_unit dbus.service required
  enable_unit elogind.service required
fi

enable_unit avahi-daemon.service
if magikos_has_systemd; then
  enable_unit systemd-resolved.service
fi
# Preserve the networking stack on an adopted OpenRC machine.
if magikos_has_systemd; then
  enable_unit NetworkManager.service
fi
# Don't let network-online.target hold up graphical.target waiting for DHCP/
# Wi-Fi association. This only applies to systemd.
if magikos_has_systemd; then
  magikos_service_mask NetworkManager-wait-online.service
fi
enable_unit power-profiles-daemon.service
# A running Artix system may use a different display manager; never switch it
# during adoption. Only the fresh systemd installer owns the SDDM alias.
if magikos_has_systemd; then
  for dm in gdm lightdm lxdm greetd ly sddm; do
    magikos_service_disable "$dm.service"
  done
  rm -f /etc/systemd/system/display-manager.service
  enable_unit sddm.service
fi
# Kill one runaway app scope instead of letting reclaim thrashing take the
# whole session down. [Install] pulls in systemd-oomd.socket via Also=, which
# is what the user manager reports app.slice candidacy over.
if magikos_has_systemd; then
  enable_unit systemd-oomd.service
fi