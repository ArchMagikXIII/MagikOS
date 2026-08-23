#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

lid_close="$ROOT/bin/magikos-system-lid-close"
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

# closed/docked are the two facts logind uses to decide whether a lid close
# suspends, so each scenario pins them and records what the lid handler did.
setup_scenario() {
  scenario_dir="$tmpdir/$1"
  mock_bin="$scenario_dir/bin"
  call_log="$scenario_dir/calls"
  mkdir -p "$mock_bin"
  : >"$call_log"

  local closed="$2" docked="$3"

  cat >"$mock_bin/magikos-hw-laptop-closed" <<SH
#!/bin/bash
exit $closed
SH
  cat >"$mock_bin/magikos-hw-external-monitors" <<SH
#!/bin/bash
exit $docked
SH
  cat >"$mock_bin/magikos-system-lock" <<SH
#!/bin/bash
echo magikos-system-lock >>"\$CALL_LOG"
SH
  chmod +x "$mock_bin"/*
}

run_lid_close() {
  CALL_LOG="$call_log" PATH="$mock_bin:$PATH" "$lid_close"
  mapfile -t calls <"$call_log"
}

# An undocked lid close is about to suspend, and logind's inhibitor window is a
# timer rather than a promise, so the lock has to start now instead of waiting
# for PrepareForSleep.
setup_scenario undocked 0 1
run_lid_close

[[ ${calls[0]} == "magikos-system-lock" ]] ||
  fail "undocked lid close locks before anything else" "calls: ${calls[*]}"
pass "undocked lid close locks before anything else"

# A docked lid close is clamshell mode: logind leaves the machine awake and the
# session stays in use on the external display, so locking it would be wrong.
setup_scenario docked 0 0
run_lid_close

[[ ${calls[*]} != *magikos-system-lock* ]] ||
  fail "docked lid close does not lock the session" "calls: ${calls[*]}"
pass "docked lid close does not lock the session"

# An open lid must never lock the machine the user is sitting at.
setup_scenario open 1 1
run_lid_close

[[ ${calls[*]} != *magikos-system-lock* ]] ||
  fail "an open lid never locks the session" "calls: ${calls[*]}"
pass "an open lid never locks the session"
