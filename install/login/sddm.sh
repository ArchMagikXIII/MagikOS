# Prevent password-based SDDM logins from creating an encrypted login keyring
# that conflicts with Magikos's passwordless default keyring behavior. Greeter
# session state is handled by autologin.sh; autologin itself is opt-in (see
# configure_login in magikos-provision-owner).
if [[ -f /etc/pam.d/sddm ]]; then
  sed -i '/-auth.*pam_gnome_keyring\.so/d' /etc/pam.d/sddm
  sed -i '/-password.*pam_gnome_keyring\.so/d' /etc/pam.d/sddm
fi
