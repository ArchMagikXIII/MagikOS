#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

installer="$ROOT/installer/magikos-install"

[[ -x $installer ]] || fail "installer is executable"
pass "installer is executable"

bash -n "$installer" || fail "installer passes a syntax check"
pass "installer parses cleanly"

usage=$("$installer" --help 2>&1) || fail "--help exits zero"
grep -q -- "--disk DEVICE" <<<"$usage" || fail "--help documents --disk" "$usage"
grep -q -- "--backend BE" <<<"$usage" || fail "--help documents --backend" "$usage"
pass "--help prints the option contract"

if "$installer" --bogus >/dev/null 2>&1; then
  fail "unknown option is rejected"
fi
pass "unknown options are rejected"

if grep -q 'OMARCHY_PATH' "$installer"; then
  fail "installer references the old OMARCHY_PATH variable"
fi
pass "installer speaks MAGIKOS_PATH only"

pass "installer smoke tests complete"
