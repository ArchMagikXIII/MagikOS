#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT

runtime_dir="$test_dir/run"
stub_bin="$test_dir/bin"
mkdir -p "$runtime_dir" "$stub_bin"

# A bound AF_UNIX socket outlives the process that bound it, which is exactly the
# corpse a dead compositor leaves behind. Binding one is the only way to get a
# file that passes -S, and the sandboxes this guard exists for are the ones that
# deny it, so treat the fixture as optional rather than fail there.
socket_bound=1
if command -v python3 >/dev/null; then
  python3 -c 'import socket, sys; socket.socket(socket.AF_UNIX).bind(sys.argv[1])' \
    "$runtime_dir/wayland-1" 2>/dev/null || socket_bound=0
else
  socket_bound=0
fi

attempts_log="$test_dir/swaymsg-attempts"

stub_swaymsg() {
  : >"$attempts_log"
  cat >"$stub_bin/swaymsg" <<STUB
#!/bin/bash
echo asked >>"$attempts_log"
exit $1
STUB
  chmod +x "$stub_bin/swaymsg"
}

attempts() {
  grep -c asked "$attempts_log" || true
}

# The guard exits the shell it runs in, so run it in a child and report back what
# it did: the skip line, or the core limit it left behind for Quickshell.
run_guard() {
  env "$@" PATH="$stub_bin:$PATH" bash -c '
    source "$1/base-test.sh"
    ulimit -c unlimited 2>/dev/null || true
    require_compositor "sample runtime test"
    printf "launched with core limit %s\n" "$(ulimit -c)"
  ' bash "$SHELL_TEST_DIR" 2>&1 || printf 'guard exited %s\n' "$?"
}

skipped="ok - no Wayland compositor; skipping sample runtime test"

output=$(run_guard -u WAYLAND_DISPLAY XDG_RUNTIME_DIR="$runtime_dir")
[[ $output == "$skipped" ]] || fail "guard skips without a display" "$output"
pass "guard skips without a display"

# The sandbox shape from the bug report: the variable comes through, the runtime
# directory does not.
output=$(run_guard WAYLAND_DISPLAY=wayland-1 XDG_RUNTIME_DIR="$test_dir/blocked")
[[ $output == "$skipped" ]] || fail "guard skips when the socket is unreachable" "$output"
pass "guard skips when the socket is unreachable"

# Everything below needs a socket to stand in for a live or abandoned compositor.
if (( ! socket_bound )); then
  pass "cannot bind a Unix socket here; skipping the cases that need one"
  exit 0
fi

# A silent compositor is gone: one failed probe decides, so the guard never
# waits on a corpse.
stub_swaymsg 1
output=$(run_guard WAYLAND_DISPLAY=wayland-1 XDG_RUNTIME_DIR="$runtime_dir" SWAYSOCK="$runtime_dir/sway-ipc.test.sock")
[[ $output == "$skipped" ]] || fail "guard skips when the compositor stopped answering" "$output"
pass "guard skips when the compositor stopped answering"

[[ $(attempts) == 1 ]] || fail "guard probes the compositor exactly once" "asked $(attempts) times"
pass "guard probes the compositor exactly once"

# Without a socket path there is nothing to ask, and a live socket is all the
# evidence there is: run rather than skip real coverage.
stub_swaymsg 1
output=$(run_guard -u SWAYSOCK -u I3SOCK WAYLAND_DISPLAY=wayland-1 XDG_RUNTIME_DIR="$runtime_dir")
[[ $output == "launched with core limit 0" ]] || fail "guard runs when swaymsg cannot be asked" "$output"
pass "guard runs when swaymsg cannot be asked"

[[ $(attempts) == 0 ]] || fail "guard leaves swaymsg alone without a socket path" "asked $(attempts) times"
pass "guard leaves swaymsg alone without a socket path"

# Quickshell aborts if the compositor disappears mid-run, so the tests it is
# about to launch must not be able to dump core.
stub_swaymsg 0
output=$(run_guard WAYLAND_DISPLAY=wayland-1 XDG_RUNTIME_DIR="$runtime_dir" SWAYSOCK="$runtime_dir/sway-ipc.test.sock")
[[ $output == "launched with core limit 0" ]] || fail "guard runs with core dumps disabled" "$output"
pass "guard runs with core dumps disabled"
