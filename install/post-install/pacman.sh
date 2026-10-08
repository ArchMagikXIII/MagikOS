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

source "${MAGIKOS_INSTALL:-$MAGIKOS_PATH/install}/helpers/platform.sh"
if magikos_is_artix; then
  # Artix's [system]/[world]/[galaxy]/[lib32] sections and mirrorlist are not
  # interchangeable with Arch's [core]/[extra]/[multilib]. Never replace them.
  echo "Artix detected; preserving existing pacman.conf and mirrorlist"
else
  cp -f "$MAGIKOS_PATH/default/pacman/pacman-${MAGIKOS_MIRROR:-stable}.conf" /etc/pacman.conf
  cp -f "$MAGIKOS_PATH/default/pacman/mirrorlist-${MAGIKOS_MIRROR:-stable}" /etc/pacman.d/mirrorlist
fi

# magikos-settings skips this override until cups-browsed is actually present
# to avoid pacman creating cups-browsed.conf.pacnew during ISO package install.
if [[ -f $MAGIKOS_PATH/etc-overrides/cups-cups-browsed.conf && -d /etc/cups ]]; then
  cp -f "$MAGIKOS_PATH/etc-overrides/cups-cups-browsed.conf" /etc/cups/cups-browsed.conf
  rm -f /etc/cups/cups-browsed.conf.pacnew
fi

source "$MAGIKOS_INSTALL/hardware/pacman.sh"
