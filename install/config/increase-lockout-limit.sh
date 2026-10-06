# /etc/pam.d/{system-auth,sddm-autologin} are upstream-owned and the changes
# are insertions, not full-file overrides, so they stay scripted.
#
# Arch splits PAM into per-service files and carries pam_faillock in
# system-auth; Debian puts the same stack in common-auth and pulls it into
# every service. Edit whichever layout is actually present -- a sed against a
# file that does not exist fails, and that would abort the rest of the config
# chain.
PAM_AUTH_FILES=()
if [[ -f /etc/pam.d/system-auth ]]; then
  PAM_AUTH_FILES+=(/etc/pam.d/system-auth)
fi
if [[ -f /etc/pam.d/common-auth ]]; then
  PAM_AUTH_FILES+=(/etc/pam.d/common-auth)
fi

for pam_auth in "${PAM_AUTH_FILES[@]}"; do
  sed -i 's|^\(auth\s\+required\s\+pam_faillock.so\)\s\+preauth.*$|\1 preauth silent deny=10 unlock_time=120|' "$pam_auth"
  sed -i 's|^\(auth\s\+\[default=die\]\s\+pam_faillock.so\)\s\+authfail.*$|\1 authfail deny=10 unlock_time=120|' "$pam_auth"
done

# Drop both lines before re-adding authsucc so reruns don't duplicate it.
# SDDM ships its own pam file only when it is installed; without it there is no
# autologin stack to harden.
if [[ -f /etc/pam.d/sddm-autologin ]]; then
  sed -i '/pam_faillock\.so preauth/d'  /etc/pam.d/sddm-autologin
  sed -i '/pam_faillock\.so authsucc/d' /etc/pam.d/sddm-autologin
  sed -i '/auth.*pam_permit\.so/a auth        required    pam_faillock.so authsucc' \
             /etc/pam.d/sddm-autologin
fi