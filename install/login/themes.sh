# Install the shipped Magikos SDDM and Plymouth themes and make Plymouth the
# default, so an install or adoption shows the branded greeter and boot splash
# instead of SDDM's embedded fallback theme and the distro's bgrt animation.
#
# Each half is independently guarded *and* independently failure-tolerant. This
# is the last leaf in login/all.sh, so anything that escapes here aborts
# magikos-apply-system before post-install/ runs at all -- and a cosmetically
# imperfect boot theme is never worth losing the magikos-dns symlink and the
# udev reload over. A failure is reported and the other half still runs.
if command -v magikos-refresh-sddm >/dev/null 2>&1 && [[ -d /usr/share/sddm ]]; then
  if ! magikos-refresh-sddm; then
    echo "Warning: the Magikos greeter theme was not applied; SDDM keeps its current theme." >&2
  fi
else
  echo "SDDM not installed; skipping greeter theme"
fi

if command -v magikos-refresh-plymouth >/dev/null 2>&1 && command -v plymouthd >/dev/null 2>&1; then
  if ! magikos-refresh-plymouth; then
    echo "Warning: the Magikos boot splash theme was not applied." >&2
  fi
else
  echo "plymouth not installed; skipping boot splash theme"
fi