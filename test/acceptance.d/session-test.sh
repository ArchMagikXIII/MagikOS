#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

# The compositor reports at least one monitor
monitors=$(swaymsg -t get_outputs -r | jq '[.[] | select(.active)] | length')
(( monitors >= 1 )) || fail "compositor reports a monitor"
pass "compositor reports a monitor"

# The Magikos shell is running and responsive
wait_until "magikos-shell responds to ping" 60 magikos-shell shell ping

# Core shell plugins are loaded
plugins=$(magikos-shell shell listPlugins)
for plugin in \
  magikos.audio magikos.background magikos.bar magikos.bluetooth \
  magikos.clipboard magikos.emojis magikos.menu \
  magikos.monitor magikos.network magikos.notifications magikos.power \
  magikos.reminders magikos.weather; do
  [[ $plugins == *"$plugin"* ]] || fail "shell plugin is loaded: $plugin" "loaded plugins: $plugins"
  pass "shell plugin is loaded: $plugin"
done

# Sway's IPC exposes no layer surfaces, so rendering is verified with pixels:
# once the shell is up, the screen must differ from the empty reference the
# runner captured at boot. The bar and background are what draw there.
[[ -s $ARTIFACTS/absent-screen-reference.png ]] || refresh_absent_reference
wait_until "bar and background render on screen" 30 screen_differs_from "$ARTIFACTS/absent-screen-reference.png"

# Hiding parks the bar without unmapping its surface, and revealing brings
# that same surface back: hiding must move the screen away from the revealed
# baseline, and revealing must return it.
restore_bar_visibility() {
  magikos-toggle-bar off >/dev/null 2>&1 || true
}
trap restore_bar_visibility EXIT

baseline="$ARTIFACTS/bar-revealed-baseline.png"
timeout 10 grim "$baseline" 2>/dev/null || fail "captured the revealed bar baseline"

magikos-toggle-bar on
wait_until "hidden bar leaves the revealed baseline" 15 screen_differs_from "$baseline"
screenshot "success-bar-hidden"

magikos-toggle-bar off
wait_until "revealed bar returns to its baseline" 15 screen_matches "$baseline"
screenshot "success-bar-revealed"
trap - EXIT

# Audio stack is up
wait_until "pipewire is running" 30 wpctl status

# Root filesystem is btrfs as installed
[[ $(findmnt -no FSTYPE /) == "btrfs" ]] || fail "root filesystem is btrfs"
pass "root filesystem is btrfs"

# Magikos reports its version
magikos-version >/dev/null || fail "magikos-version works"
pass "magikos-version works"

# No failed units, system or user. MAGIKOS_ACCEPTANCE_IGNORE_UNITS can hold a
# regex of units to overlook (useful on dev machines; a fresh VM should be clean).
failed_units() {
  systemctl "$@" --failed --no-legend --plain | awk '{print $1}' |
    grep -Ev "${MAGIKOS_ACCEPTANCE_IGNORE_UNITS:-^$}" || true
}

failed_system=$(failed_units --system)
if [[ -n $failed_system ]]; then
  fail "no failed system units" "failed units: $failed_system"
fi
pass "no failed system units"

failed_user=$(failed_units --user)
if [[ -n $failed_user ]]; then
  fail "no failed user units" "failed units: $failed_user"
fi
pass "no failed user units"

screenshot "success-desktop"
