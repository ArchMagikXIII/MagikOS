#!/bin/bash
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/base-test.sh"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/runtime" "$tmp/user-init"
export TEST_LOG="$tmp/calls"
cat >"$tmp/bin/sway" <<'STUB'
#!/bin/bash
printf 'session:%s:%s:%s:%s\n' "$MAGIKOS_PATH" "$XDG_CURRENT_DESKTOP" "$MAGIKOS_FORCE_DIRECT_LAUNCH" "$DBUS_SESSION_BUS_ADDRESS" >>"$TEST_LOG"
STUB
cat >"$tmp/bin/foot" <<'STUB'
#!/bin/bash
printf 'foot:%s\n' "$*" >>"$TEST_LOG"
STUB
cat >"$tmp/bin/rc-update" <<'STUB'
#!/bin/bash
printf 'rc-update:%s\n' "$*" >>"$TEST_LOG"
STUB
cat >"$tmp/bin/rc-service" <<'STUB'
#!/bin/bash
printf 'rc-service:%s\n' "$*" >>"$TEST_LOG"
[[ ${3:-} != status ]]
STUB
chmod +x "$tmp/bin/"*

MAGIKOS_PATH="$ROOT" PATH="$tmp/bin:$PATH" XDG_RUNTIME_DIR="$tmp/runtime" \
DBUS_SESSION_BUS_ADDRESS=unix:path=/test/bus \
  "$ROOT/bin/magikos-openrc-session"
grep -Fqx "session:$ROOT:sway:1:unix:path=/test/bus" "$TEST_LOG" || fail "OpenRC session exports Wayland, Magikos and D-Bus environment"
pass "OpenRC session exports its environment before launching Sway"

MAGIKOS_FORCE_DIRECT_LAUNCH=1 "$ROOT/bin/uwsm-app" -- bash -c 'printf "direct-launch\n" >>"$TEST_LOG"'
grep -Fqx direct-launch "$TEST_LOG" || fail "OpenRC app launcher executes the actual command"
MAGIKOS_FORCE_FOOT_TERMINAL=1 PATH="$tmp/bin:$PATH" "$ROOT/bin/xdg-terminal-exec" --app-id=test --dir=/work -e bash -l
[[ $(MAGIKOS_FORCE_FOOT_TERMINAL=1 "$ROOT/bin/xdg-terminal-exec" --print-id) == foot.desktop ]] || fail "Foot fallback reports its desktop ID"
grep -Fqx 'foot:--app-id=test --working-directory=/work bash -l' "$TEST_LOG" || fail "Foot fallback translates launcher arguments"
pass "direct app and terminal fallback work without a systemd user manager"

: >"$tmp/user-init/pipewire"
: >"$tmp/user-init/wireplumber"
MAGIKOS_OPENRC_USER_INIT_DIR="$tmp/user-init" PATH="$tmp/bin:$PATH" \
  "$ROOT/bin/magikos-openrc-user-services"
for service in pipewire wireplumber; do
  grep -Fqx "rc-update:--user add $service default" "$TEST_LOG" || fail "OpenRC user service $service is enabled"
  grep -Fqx "rc-service:--user $service start" "$TEST_LOG" || fail "OpenRC user service $service is started"
done
! grep -q 'pipewire-pulse' "$TEST_LOG" || fail "PulseAudio replacement isn't started unless already installed"
pass "OpenRC user services start packaged PipeWire scripts only"

# No Artix code path should call the Arch hardware/config/post-install chain.
grep -Fq 'if (( ARTIX_OPENRC )); then' "$ROOT/installer/magikos-install" || fail "installer selects an Artix-specific branch"
grep -Fq 'install_packages_host' "$ROOT/installer/magikos-install" || fail "installer still installs the selected manifest"
grep -Fq 'bash "$PLANTED/install/artix-openrc/apply.sh"' "$ROOT/installer/magikos-install" || fail "installer uses dedicated Artix setup"
pass "existing-system Artix path does not call the Arch system finalizer"
