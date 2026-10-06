# Ensure we use system python3 and not mise's python3
if [[ -f /usr/bin/powerprofilesctl ]]; then
  # magikos-apply-system already runs as root; only reach for sudo when an
  # actual password prompt could be needed (a minimal chroot has no sudo).
  if (( EUID == 0 )); then
    sed -i '/env python3/ c\#!/bin/python3' /usr/bin/powerprofilesctl
  else
    sudo sed -i '/env python3/ c\#!/bin/python3' /usr/bin/powerprofilesctl
  fi
fi
