#!/bin/bash
# Minimal Artix adoption step. Do not run the Arch-oriented magikos-apply-system
# here: it edits initramfs, Snapper, network, display-manager and pacman state.
set -euo pipefail
source "${MAGIKOS_INSTALL:-/usr/share/magikos/install}/helpers/systemd.sh"

[[ $(magikos_detect_init) == openrc ]] || {
  echo "Artix OpenRC service setup requires a running OpenRC host" >&2
  exit 1
}
for service in dbus elogind; do
  magikos_openrc_has_service "$service" || {
    echo "Missing /etc/init.d/$service; install its Artix -openrc package" >&2
    exit 1
  }
done

# Enable only the existing session prerequisites for the NEXT boot. Installing
# optional service packages does not authorize us to switch the live machine's
# network, firewall, display manager or audio server behind the user's back.
magikos_service_enable dbus
magikos_service_enable elogind
echo "OpenRC dbus and elogind enabled for next boot; other host services unchanged"
