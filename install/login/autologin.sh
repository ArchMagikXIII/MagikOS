# Substitute the real installed user into the shipped SDDM autologin drop-in.
#
# The etc/ tree ships /etc/sddm.conf.d/autologin.conf with a literal USERNAME
# placeholder (the ISO substitutes it on its own path). Every other install
# route runs this leaf so a fresh boot can never attempt — and crash on —
# autologin as an account literally named "USERNAME".
#
# Deferred-provisioning installs skip this: the account does not exist until
# first boot, and magikos-provision-owner's configure_login writes autologin
# with the actual owner at that point.
[[ -n $MAGIKOS_INSTALL_USER ]] || return 0

config=/etc/sddm.conf.d/autologin.conf

# Only touch the file while it still carries the placeholder. An ISO or
# provisioner that already wrote the real account keeps its own choice.
[[ -f $config ]] || return 0
grep -q '^User=USERNAME$' "$config" || return 0

mkdir -p /etc/sddm.conf.d
user=${MAGIKOS_INSTALL_USER//&/\\&}
sed -i "s/^User=USERNAME$/User=$user/" "$config"

# Keep SDDM's remembered-session state pointing at the real account too, so a
# user that walked away from the greeter isn't asked to re-pick a session.
mkdir -p /var/lib/sddm
printf '[Last]\nSession=sway\nUser=%s\n' "$MAGIKOS_INSTALL_USER" >/var/lib/sddm/state.conf
chown -R sddm:sddm /var/lib/sddm 2>/dev/null || true

# Encrypted installs keep autologin permanently (the LUKS prompt is the auth
# boundary). Unencrypted installs autologin only this first boot, then a
# one-shot service removes the drop-in so later boots use the normal SDDM
# login and the disk isn't left permanently open.
[[ -f /etc/crypttab ]] && return 0

unit=magikos-provision-autologin-once.service
cat >/etc/systemd/system/$unit <<UNIT
[Unit]
Description=Drop the first-boot autologin before the next login
Before=display-manager.service
ConditionPathExists=/etc/sddm.conf.d/autologin.conf

[Service]
Type=oneshot
ExecStart=/usr/bin/rm -f /etc/sddm.conf.d/autologin.conf
ExecStartPost=/usr/bin/rm -f /etc/systemd/system/graphical.target.wants/$unit /etc/systemd/system/$unit

[Install]
WantedBy=graphical.target
UNIT
mkdir -p /etc/systemd/system/graphical.target.wants
ln -sf "../$unit" "/etc/systemd/system/graphical.target.wants/$unit"