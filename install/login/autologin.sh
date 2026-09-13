# Point SDDM's remembered-session state at the freshly installed account so the
# greeter lands on the sway session without asking the user to re-pick it.
#
# Autologin itself is opt-in and off by default, so nothing here creates it:
# provision-owner's configure_login writes the drop-in only when the owner
# chose "log me in automatically", and magikos-install only with --autologin.
# A fresh install therefore always boots to the MagikOS login with the password
# prompt.
[[ -n $MAGIKOS_INSTALL_USER ]] || return 0

mkdir -p /var/lib/sddm
printf '[Last]\nSession=sway\nUser=%s\n' "$MAGIKOS_INSTALL_USER" >/var/lib/sddm/state.conf
chown -R sddm:sddm /var/lib/sddm 2>/dev/null || true