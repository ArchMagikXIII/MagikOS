#!/bin/bash

# Raise the Logitech G435 on-board playback gain to its maximum (175/175, 0 dB).
#
# The headset ships with a hardware volume limiter at 147/175 (~ -10 dB) that
# Windows' G HUB lifts automatically; nothing lifts it on Linux, so the headset
# is quieter than on Windows at any system volume. The udev rule runs this
# program on every connect to re-arm the peak volume across replugs and reboots.

for id_file in /sys/class/sound/card*/id; do
  if [[ -r $id_file && $(cat "$id_file") == "Headset" ]]; then
    card=${id_file%/id}
    card=${card##*/card}
    amixer -c "$card" cset name='G435 Wireless Gaming Headset Playback Volume' 175 >/dev/null 2>&1
  fi
done