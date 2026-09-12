# Lift the Logitech G435 hardware volume limiter.
#
# The headset's on-board playback gain ships at 147/175 (~ -10 dB) and nothing
# on Linux raises it, so it is quieter than on Windows where G HUB manages the
# same control. A udev rule re-raises it to 0 dB on every connect.

if magikos-hw-g435; then
  sudo mkdir -p /etc/udev/rules.d
  sudo cp -f "$MAGIKOS_PATH/default/udev/70-magikos-g435-volume.rules" /etc/udev/rules.d/70-magikos-g435-volume.rules
fi