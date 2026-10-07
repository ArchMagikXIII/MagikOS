SNAPPER_CONFIG_PATH="${MAGIKOS_SNAPPER_CONFIG_PATH:-/etc/snapper/configs/root}"
SNAPPER_CONF_PATH="${MAGIKOS_SNAPPER_CONF_PATH:-/etc/conf.d/snapper}"
template="${MAGIKOS_SNAPPER_TEMPLATE:-${MAGIKOS_PATH:-/usr/share/magikos}/default/snapper/root}"

echo "Configuring Magikos Snapper snapshot retention"

# snapper needs btrfs subvolumes to be useful and is not in every base set --
# the Debian list leaves the root filesystem choice to the administrator. With
# no snapper there is nothing to configure, and create-config would fail and
# abort the chain.
if ! command -v snapper >/dev/null 2>&1; then
  echo "snapper not installed; skipping snapshot configuration"
  return 0
fi

if [[ ! -f $SNAPPER_CONFIG_PATH ]]; then
  mkdir -p "$(dirname "$SNAPPER_CONFIG_PATH")"

  if [[ ${MAGIKOS_SNAPPER_CONFIGURE_TEST:-0} == "1" ]]; then
    : >"$SNAPPER_CONFIG_PATH"
  else
    snapper --no-dbus -c root create-config / >/dev/null 2>&1 || snapper -c root create-config / >/dev/null
  fi
fi

install -m 0644 "$template" "$SNAPPER_CONFIG_PATH"

mkdir -p "$(dirname "$SNAPPER_CONF_PATH")"
printf '%s\n' 'SNAPPER_CONFIGS="root"' >"$SNAPPER_CONF_PATH"
chmod 0644 "$SNAPPER_CONF_PATH"

source "${MAGIKOS_INSTALL_HELPERS:-${MAGIKOS_INSTALL:-/usr/share/magikos}/install/helpers}/systemd.sh"
if magikos_has_systemd; then
  systemctl disable --now snapper-timeline.timer >/dev/null 2>&1 || true
  systemctl enable --now snapper-cleanup.timer >/dev/null 2>&1 || true
  # limine-snapper-sync is a MagikOS/CachyOS package with no Debian counterpart,
  # so enable it only where the unit exists.
  systemctl enable --now limine-snapper-sync.service >/dev/null 2>&1 || true
else
  magikos_skip_systemd "snapper.sh: not a systemd system"
fi
