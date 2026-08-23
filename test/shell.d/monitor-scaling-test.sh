#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

test_tmp=$(mktemp -d)
trap 'rm -rf "$test_tmp"' EXIT

stub_bin="$test_tmp/bin"
swaymsg_log="$test_tmp/swaymsg-calls"
state_dir="$test_tmp/home/.local/state"
scale_log="$state_dir/magikos/monitor-scaling.log"

mkdir -p "$stub_bin"

cat >"$stub_bin/swaymsg" <<'SH'
#!/bin/bash

if [[ $1 == "-t" && $2 == "get_outputs" ]]; then
  printf '[{"name":"eDP-1","focused":true,"scale":%s,"current_mode":{"width":%s,"height":%s,"refresh":120000}}]\n' \
    "${MAGIKOS_TEST_MONITOR_SCALE:-2}" "${MAGIKOS_TEST_MONITOR_WIDTH:-2880}" "${MAGIKOS_TEST_MONITOR_HEIGHT:-1800}"
elif [[ $1 == "output" && $3 == "scale" ]]; then
  printf '%s\n' "$*" >>"$MAGIKOS_TEST_SWAYMSG_LOG"
else
  exit 1
fi
SH
chmod +x "$stub_bin/swaymsg"

run_scaling() {
  HOME="$test_tmp/home" \
    XDG_STATE_HOME="$state_dir" \
    PATH="$stub_bin:$PATH" \
    MAGIKOS_TEST_SWAYMSG_LOG="$swaymsg_log" \
    MAGIKOS_TEST_MONITOR_SCALE="${MAGIKOS_TEST_MONITOR_SCALE:-2}" \
    "$ROOT/bin/magikos-sway-monitor-scaling" "$@"
}

assert_sway_call() {
  local expected="$1" description="$2"

  grep -Fx "$expected" "$swaymsg_log" >/dev/null ||
    fail "$description" "expected call: $expected"$'\n'"calls: $(<"$swaymsg_log")"
}

: >"$swaymsg_log"
MAGIKOS_TEST_MONITOR_SCALE=2 run_scaling up
assert_sway_call 'output eDP-1 scale 3' "monitor scaling up reaches 3x"
grep -F $'requested=up\tcurrent=2\tnew=3\tmonitor=eDP-1' "$scale_log" >/dev/null || fail "monitor scaling up writes audit log"
pass "monitor scaling up reaches 3x"

: >"$swaymsg_log"
MAGIKOS_TEST_MONITOR_SCALE=3 run_scaling down
assert_sway_call 'output eDP-1 scale 2' "monitor scaling down recovers 3x to 2x"
pass "monitor scaling down recovers 3x to 2x"

: >"$swaymsg_log"
MAGIKOS_TEST_MONITOR_SCALE=3.0000000000000004 run_scaling down
assert_sway_call 'output eDP-1 scale 2' "monitor scaling down snaps floating point 3x to 2x"
pass "monitor scaling down snaps floating point 3x to 2x"

: >"$swaymsg_log"
MAGIKOS_TEST_MONITOR_SCALE=2 run_scaling 3
assert_sway_call 'output eDP-1 scale 3' "monitor scaling explicit 3x remains available"
pass "monitor scaling explicit 3x remains available"

: >"$swaymsg_log"
MAGIKOS_TEST_MONITOR_SCALE=2 run_scaling 1.6
assert_sway_call 'output eDP-1 scale 1.6' "monitor scaling explicit 1.6x remains available"
pass "monitor scaling explicit 1.6x remains available"

scale=$(MAGIKOS_TEST_MONITOR_SCALE=3 run_scaling)
[[ $scale == "3" ]] || fail "monitor scaling reports explicit 3x scale" "actual: $scale"
pass "monitor scaling reports explicit 3x scale"

scale=$(MAGIKOS_TEST_MONITOR_SCALE=3.2 run_scaling)
[[ $scale == "3.2" ]] || fail "monitor scaling reports the actual non-preset scale" "actual: $scale"
pass "monitor scaling reports the actual non-preset scale"

# 1280x800 approximates the 3x preset as 3.2x.
: >"$swaymsg_log"
MAGIKOS_TEST_MONITOR_SCALE=2 MAGIKOS_TEST_MONITOR_WIDTH=1280 MAGIKOS_TEST_MONITOR_HEIGHT=800 run_scaling 3
assert_sway_call 'output eDP-1 scale 3.2' "monitor scaling approximates explicit 3x as 3.2x"
pass "monitor scaling approximates explicit 3x as 3.2x"

: >"$swaymsg_log"
MAGIKOS_TEST_MONITOR_SCALE=2 MAGIKOS_TEST_MONITOR_WIDTH=1280 MAGIKOS_TEST_MONITOR_HEIGHT=800 run_scaling up
assert_sway_call 'output eDP-1 scale 3.2' "monitor scaling up reaches approximated 3.2x"
pass "monitor scaling up reaches approximated 3.2x"

: >"$swaymsg_log"
MAGIKOS_TEST_MONITOR_SCALE=4 MAGIKOS_TEST_MONITOR_WIDTH=1280 MAGIKOS_TEST_MONITOR_HEIGHT=800 run_scaling down
assert_sway_call 'output eDP-1 scale 3.2' "monitor scaling down reaches approximated 3.2x"
pass "monitor scaling down reaches approximated 3.2x"

: >"$swaymsg_log"
MAGIKOS_TEST_MONITOR_SCALE=2 MAGIKOS_TEST_MONITOR_WIDTH=6016 MAGIKOS_TEST_MONITOR_HEIGHT=3384 run_scaling 1.25
grep -F 'output eDP-1 scale 1.33333' "$swaymsg_log" >/dev/null || fail "monitor scaling approximates explicit 1.25x"
pass "monitor scaling approximates explicit 1.25x"

: >"$swaymsg_log"
MAGIKOS_TEST_MONITOR_SCALE=2 MAGIKOS_TEST_MONITOR_WIDTH=1280 MAGIKOS_TEST_MONITOR_HEIGHT=800 run_scaling 3.2
assert_sway_call 'output eDP-1 scale 3.2' "monitor scaling accepts displayed approximate values"
pass "monitor scaling accepts displayed approximate values"

# On a mode where both 3x and 4x resolve to 4x, the duplicate is one step.
: >"$swaymsg_log"
MAGIKOS_TEST_MONITOR_SCALE=4 MAGIKOS_TEST_MONITOR_WIDTH=1280 MAGIKOS_TEST_MONITOR_HEIGHT=804 run_scaling down
assert_sway_call 'output eDP-1 scale 2' "monitor scaling down skips duplicate 4x approximation"
pass "monitor scaling down skips duplicate approximation"
