# Install the shipped Magikos SDDM and Plymouth themes and make Plymouth the
# default, so an install or adoption shows the branded greeter and boot splash
# instead of SDDM's embedded fallback theme and the distro's bgrt animation.
#
# The refresh helpers are idempotent and rebuild plymouthd's initramfs when a
# rebuilding tool is present, so this is safe to run on every install path.
magikos-refresh-sddm
magikos-refresh-plymouth