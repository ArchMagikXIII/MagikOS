#!/bin/bash
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/base-test.sh"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/init.d"

cat >"$tmp/bin/rc-update" <<'STUB'
#!/bin/bash
printf 'rc-update %s\n' "$*" >>"$TEST_LOG"
if [[ ${1:-} == add && ${2:-} == "${RC_FAIL_SERVICE:-}" ]]; then
  exit 1
fi
STUB
cat >"$tmp/bin/rc-service" <<'STUB'
#!/bin/bash
printf 'rc-service %s\n' "$*" >>"$TEST_LOG"
[[ ${2:-} == status ]] && echo 'started'
STUB
cat >"$tmp/bin/systemctl" <<'STUB'
#!/bin/bash
printf 'systemctl %s\n' "$*" >>"$TEST_LOG"
case "${1:-}" in
  is-system-running) echo running ;;
  list-unit-files)
    [[ ${2:-} == "${SYSTEMD_MISSING:-}" ]] || printf '%s enabled\n' "$2"
    ;;
esac
STUB
# The systemd branch removes a real display-manager alias. Intercept that
# operation so this test cannot change the host even if run as root.
cat >"$tmp/bin/rm" <<'STUB'
#!/bin/bash
printf 'rm %s\n' "$*" >>"$TEST_LOG"
STUB
chmod +x "$tmp/bin/"*
export TEST_LOG="$tmp/calls" MAGIKOS_INSTALL_HELPERS="$ROOT/install/helpers"
export MAGIKOS_OPENRC_INIT_DIR="$tmp/init.d" MAGIKOS_NO_RUNIT=1
mock_path="$tmp/bin:$PATH"
config="$ROOT/install/config/enable-services.sh"

[[ $(env PATH="$mock_path" MAGIKOS_NO_SYSTEMD=1 MAGIKOS_NO_OPENRC=0 \
  bash -c 'source "$MAGIKOS_INSTALL_HELPERS/systemd.sh"; magikos_detect_init') == openrc ]] ||
  fail "init detection finds OpenRC in the stub environment"
[[ $(env PATH="$mock_path" MAGIKOS_NO_SYSTEMD=0 MAGIKOS_NO_OPENRC=1 \
  bash -c 'source "$MAGIKOS_INSTALL_HELPERS/systemd.sh"; magikos_detect_init') == systemd ]] ||
  fail "init detection still finds systemd"
pass "init detection respects the selected service manager"

openrc_config() {
  env PATH="$mock_path" MAGIKOS_NO_SYSTEMD=1 MAGIKOS_NO_OPENRC=0 \
    bash -e "$config" >"$tmp/output" 2>&1
}
systemd_config() {
  env PATH="$mock_path" MAGIKOS_NO_SYSTEMD=0 MAGIKOS_NO_OPENRC=1 \
    bash -e "$config" >"$tmp/output" 2>&1
}
expect_call() {
  grep -Fxq "$1" "$TEST_LOG" || fail "missing call: $1" "$(cat "$TEST_LOG")"
}
no_call() {
  if grep -Eq "$1" "$TEST_LOG"; then
    fail "unexpected call matching: $1" "$(cat "$TEST_LOG")"
  fi
}

# A populated Artix init.d: adding links is safe even on a live installer.
for service in dbus elogind NetworkManager sddm avahi-daemon power-profiles-daemon bluetoothd; do
  : >"$tmp/init.d/$service"
done
: >"$TEST_LOG"
openrc_config || fail "OpenRC configuration succeeds" "$(cat "$tmp/output")"
for service in dbus avahi-daemon power-profiles-daemon; do
  expect_call "rc-update add $service default"
done
expect_call 'rc-update add elogind boot'
expect_call 'rc-update del elogind default'
no_call 'systemctl|rc-service|^rm |systemd-resolved|systemd-oomd|wait-online|rc-update (add|del) (bluetooth|NetworkManager|sddm|gdm|lightdm|lxdm|greetd|ly)'
pass "OpenRC enables installed services in their runlevels without systemd-only actions or daemon restarts"

# The hardware bluetooth leaf calls the generic helper with the systemd name.
: >"$TEST_LOG"
env PATH="$mock_path" MAGIKOS_NO_SYSTEMD=1 MAGIKOS_NO_OPENRC=0 \
  bash -e -c 'source "$MAGIKOS_INSTALL_HELPERS/systemd.sh"; magikos_service_enable bluetooth.service; magikos_service_disable bluetooth; magikos_service_is_active bluetooth' \
  >"$tmp/output" || fail "OpenRC helper translates Bluetooth service names"
expect_call 'rc-update add bluetoothd default'
expect_call 'rc-update del bluetoothd default'
expect_call 'rc-service bluetoothd status'
no_call 'rc-service .* (start|stop)'
pass "generic helper normalizes BlueZ to bluetoothd and queries OpenRC status"

rm -f "$tmp/init.d/avahi-daemon" "$tmp/init.d/power-profiles-daemon" "$tmp/init.d/NetworkManager" "$tmp/init.d/sddm"
: >"$TEST_LOG"
openrc_config || fail "missing optional OpenRC services can be skipped" "$(cat "$tmp/output")"
no_call 'rc-update (add|del) (avahi-daemon|power-profiles-daemon|NetworkManager|sddm)'
expect_call 'rc-update add dbus default'
expect_call 'rc-update add elogind boot'
pass "missing optional OpenRC init scripts are skipped"

rm -f "$tmp/init.d/dbus"
: >"$TEST_LOG"
if openrc_config; then fail "missing dbus-openrc init script must fail"; fi
grep -q 'dbus init script missing' "$tmp/output" || fail "missing dbus error explains the failure"
no_call 'rc-update add elogind'
: >"$tmp/init.d/dbus"
rm -f "$tmp/init.d/elogind"
if openrc_config; then fail "missing elogind-openrc init script must fail"; fi
grep -q 'elogind init script missing' "$tmp/output" || fail "missing elogind error explains the failure"
: >"$tmp/init.d/elogind"
pass "required dbus and elogind init scripts cannot silently disappear"

: >"$TEST_LOG"
if RC_FAIL_SERVICE=elogind openrc_config; then
  fail "failed elogind boot enable must abort"
fi
expect_call 'rc-update add elogind boot'
no_call 'rc-update del elogind default'
pass "a failed elogind boot enable leaves its old default link alone"

pass "adoption leaves the existing network and display-manager runlevels alone"

: >"$TEST_LOG"
SYSTEMD_MISSING=avahi-daemon.service systemd_config || fail "systemd enablement still works" "$(cat "$tmp/output")"
expect_call 'systemctl enable systemd-resolved.service'
expect_call 'systemctl enable NetworkManager.service'
expect_call 'systemctl mask NetworkManager-wait-online.service'
expect_call 'systemctl disable sddm.service'
expect_call 'rm -f /etc/systemd/system/display-manager.service'
expect_call 'systemctl enable sddm.service'
expect_call 'systemctl enable systemd-oomd.service'
no_call 'rc-update|rc-service|systemctl (start|stop|restart)|systemctl enable (dbus|elogind).service'
pass "systemd keeps its existing unit enablement and display-manager alias flow"
