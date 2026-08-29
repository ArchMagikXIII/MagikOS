#!/bin/bash

set -euo pipefail

source "$(dirname "$0")/base-test.sh"

test_tmp=$(mktemp -d)
trap 'rm -rf "$test_tmp"' EXIT

stub_bin="$test_tmp/bin"
test_home="$test_tmp/home"
runtime_dir="$test_tmp/runtime"
mkdir -p "$stub_bin" "$test_home" "$runtime_dir"

run_with_lock_env() {
  HOME="$test_home" \
  XDG_RUNTIME_DIR="$runtime_dir" \
  XDG_STATE_HOME="$test_tmp/state" \
  PATH="$stub_bin:$ROOT/bin:$PATH" \
    "$@"
}

write_stub() {
  local name="$1"
  local body="$2"

  cat >"$stub_bin/$name" <<SH
#!/bin/bash
$body
SH
  chmod +x "$stub_bin/$name"
}

# magikos-update no longer owns the Stay Awake/restart machinery; topgrade
# drives the whole update. These tests exercise the standalone stay-awake
# helper, which other callers (e.g. a terminal session) still use.

# Stale cleanup state from a killed update must not override a Stay Awake choice
# the user made afterward.
stay_awake_helper_state="$runtime_dir/magikos-update-stay-awake"
stay_awake_state="$test_home/.local/state/magikos/indicators/stay-awake"
mkdir -p "$stay_awake_helper_state" "$(dirname "$stay_awake_state")"
printf '%s\n' "old-update-owner" >"$stay_awake_helper_state/idle-owner"
printf '%s\n' "user-choice" >"$stay_awake_state"

run_with_lock_env "$ROOT/bin/magikos-update-stay-awake" stop
[[ $(<"$stay_awake_state") == "user-choice" ]] ||
  fail "stale update ownership does not remove a newer Stay Awake choice"
pass "stale update ownership preserves a newer Stay Awake choice"

# A stale PID is safe even if it has been reused by another process.
sleep 30 &
unrelated_pid=$!
unrelated_start_time=$(awk '{ print $22 }' "/proc/$unrelated_pid/stat")
mkdir -p "$stay_awake_helper_state"
printf '%s %s\n' "$unrelated_pid" "$((unrelated_start_time + 1))" >"$stay_awake_helper_state/inhibit-pid"

run_with_lock_env "$ROOT/bin/magikos-update-stay-awake" stop
kill -0 "$unrelated_pid" 2>/dev/null ||
  fail "stale inhibitor state does not terminate a reused PID"
kill "$unrelated_pid"
wait "$unrelated_pid" 2>/dev/null || true
pass "stale inhibitor state does not terminate a reused PID"
