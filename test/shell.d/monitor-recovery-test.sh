#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

monitor_laptop="$ROOT/bin/magikos-sway-monitor-laptop"
monitor_external_active="$ROOT/bin/magikos-sway-monitor-external-active"
lock_service="$ROOT/shell/plugins/lock/Service.qml"
hw_clamshell="$ROOT/bin/magikos-hw-clamshell"
hw_laptop_closed="$ROOT/bin/magikos-hw-laptop-closed"

grep -F 'magikos-hw-laptop-closed && magikos-hw-external-monitors' "$hw_clamshell" >/dev/null
grep -F '/proc/acpi/button/lid/*/state' "$hw_laptop_closed" >/dev/null
pass "clamshell helper detects closed-lid external monitor state"

# Sway reports mirrored outputs alongside their real ones, so a plain query
# still sees an active external while it mirrors the laptop panel.
grep -F 'swaymsg -t get_outputs -r' "$monitor_external_active" >/dev/null
grep -F 'select(.name | test("^(eDP|LVDS|DSI)-") | not)' "$monitor_external_active" >/dev/null
grep -F 'select(.active == true)' "$monitor_external_active" >/dev/null
pass "active external monitor helper ignores monitors disabled on purpose"

grep -F 'swaymsg -t get_outputs -r' "$monitor_laptop" >/dev/null
grep -F 'test("^(eDP|LVDS|DSI)-")' "$monitor_laptop" >/dev/null
pass "laptop monitor helper names the built-in display, including disabled outputs"

grep -F 'lock-pending: no-real-screen' "$lock_service" >/dev/null
grep -F 'lock-pending: screen-stabilizing' "$lock_service" >/dev/null
grep -F 'id: sessionLockStabilizeTimer' "$lock_service" >/dev/null
grep -Pzo 'function onScreensChanged\(\) \{\n(.*\n)*?\s*root\.requestSessionLock\(\)\n' "$lock_service" >/dev/null
grep -F 'realScreens: root.realScreenCount()' "$lock_service" >/dev/null
pass "lock service waits for stable real screens before session lock"
