# Configure pacman after package installation completes. Offline target package
# installs use the live ISO's offline pacman.conf until this final restore.
#
# Nothing to do on a non-pacman system: this leaf runs unconditionally in the
# post-install chain, and a bare cp to a /etc/pacman.conf that does not exist
# would abort every later leaf under run_logged's errexit. The MagikOS Debian
# installer plants this same tree, so the guard has to live here rather than in
# the caller's chain.
source "$MAGIKOS_PATH/bin/magikos-pkg-backend"

if ! backend_is_pacman; then
  return 0
fi

cp -f "$MAGIKOS_PATH/default/pacman/pacman-${MAGIKOS_MIRROR:-stable}.conf" /etc/pacman.conf
cp -f "$MAGIKOS_PATH/default/pacman/mirrorlist-${MAGIKOS_MIRROR:-stable}" /etc/pacman.d/mirrorlist

# On Artix, the cachyos-keyring package may not be available or may conflict
# with the Artix keyring. Manually add the CachyOS signing key if the repo
# is configured but the key isn't trusted yet.
if grep -q '^\[cachyos\]' /etc/pacman.conf; then
  # Ensure cachyos-mirrorlist exists (may not be installed on Artix)
  if [[ ! -f /etc/pacman.d/cachyos-mirrorlist ]]; then
    echo "Creating CachyOS mirrorlist..."
    cat > /etc/pacman.d/cachyos-mirrorlist <<'EOF'
Server = https://cdn77.cachyos.org/repo/x86_64/cachyos
Server = https://mirror.cachyos.org/repo/x86_64/cachyos
EOF
  fi

  # Add CachyOS signing key if not already trusted
  if ! pacman-key --list-keys 2>/dev/null | grep -q 'CachyOS'; then
    echo "Adding CachyOS signing key..."
    # CachyOS master signing key (F3B607488DB35A47)
    pacman-key --recv-keys F3B607488DB35A47 --keyserver keyserver.ubuntu.com 2>/dev/null || true
    pacman-key --lsign-key F3B607488DB35A47 2>/dev/null || true
  fi
fi

# magikos-settings skips this override until cups-browsed is actually present
# to avoid pacman creating cups-browsed.conf.pacnew during ISO package install.
if [[ -f $MAGIKOS_PATH/etc-overrides/cups-cups-browsed.conf && -d /etc/cups ]]; then
  cp -f "$MAGIKOS_PATH/etc-overrides/cups-cups-browsed.conf" /etc/cups/cups-browsed.conf
  rm -f /etc/cups/cups-browsed.conf.pacnew
fi

source "$MAGIKOS_INSTALL/hardware/pacman.sh"