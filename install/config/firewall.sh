# Allow nothing in, everything out.
#
# ufw is not part of every MagikOS base set -- the Debian list leaves it to the
# administrator -- so this leaf no-ops when the firewall is not installed
# instead of failing and aborting the rest of the post-install chain.
if ! command -v ufw >/dev/null 2>&1; then
  echo "ufw not installed; skipping firewall configuration"
  return 0
fi

ufw default deny incoming
ufw default allow outgoing

# Allow ports for LocalSend.
ufw allow 53317/udp
ufw allow 53317/tcp

# Installs are followed by reboot, so configure UFW to start on the installed
# system instead of mutating the live install session's firewall.
sed -i 's/^ENABLED=.*/ENABLED=yes/' /etc/ufw/ufw.conf
systemctl enable ufw