#!/bin/bash

set -euo pipefail

source "$(dirname "$0")/base-test.sh"

unset MAGIKOS_UPDATE_FORCE
unset TEST_AVAILABLE_BYTES
unset TEST_DF_INVALID

test_tmp=$(mktemp -d)
trap 'rm -rf "$test_tmp"' EXIT

stub_bin="$test_tmp/bin"
mkdir -p "$stub_bin"

write_stub() {
  local name="$1"
  local body="$2"

  cat >"$stub_bin/$name" <<SH
#!/bin/bash
$body
SH
  chmod +x "$stub_bin/$name"
}

write_stub df '
if (( TEST_DF_INVALID )); then
  printf "Avail\nunknown\n"
else
  printf "Avail\n%s\n" "$TEST_AVAILABLE_BYTES"
fi'

run_free_space_check() {
  PATH="$stub_bin:$ROOT/bin:$PATH" \
  LC_ALL=C \
  TEST_AVAILABLE_BYTES=${TEST_AVAILABLE_BYTES:-$((9 * 1024 * 1024 * 1024))} \
  TEST_DF_INVALID=${TEST_DF_INVALID:-0} \
  MAGIKOS_UPDATE_FORCE=${MAGIKOS_UPDATE_FORCE:-0} \
    "$ROOT/bin/magikos-update-requires-free-space"
}

set +e
output=$(TEST_AVAILABLE_BYTES=$((9 * 1024 * 1024 * 1024)) run_free_space_check)
status=$?
set -e
(( status == 1 )) || fail "free-space helper exits non-zero when disk space is low"
[[ $output == *"You need at least 10 GiB free to safely update Magikos."* ]] || fail "low disk space emits a warning"
pass "free-space helper reports low disk space through its exit status"

set +e
output=$(MAGIKOS_UPDATE_FORCE=1 run_free_space_check)
status=$?
set -e
(( status == 0 )) || fail "forced update skips the free-space requirement"
[[ -z $output ]] || fail "forced update does not emit the free-space warning"
pass "forced update skips the free-space requirement"

set +e
output=$(TEST_AVAILABLE_BYTES=$((10 * 1024 * 1024 * 1024)) run_free_space_check)
status=$?
set -e
(( status == 0 )) || fail "space equal to the threshold passes the check"
[[ $output != *"You need at least 10 GiB free"* ]] || fail "space equal to the threshold does not produce a warning"
pass "disk-space threshold includes the exact boundary"

set +e
output=$(TEST_DF_INVALID=1 run_free_space_check)
status=$?
set -e
(( status == 0 )) || fail "failed disk-space detection does not fail the check"
[[ -z $output ]] || fail "failed disk-space detection remains silent"
pass "failed disk-space detection silently continues"
