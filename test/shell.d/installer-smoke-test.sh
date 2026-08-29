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
grep -q -- "--existing" <<<"$usage" || fail "--help documents --existing" "$usage"
pass "--help prints the option contract"

if "$installer" --bogus >/dev/null 2>&1; then
  fail "unknown option is rejected"
fi
pass "unknown options are rejected"

if grep -q 'OMARCHY_PATH' "$installer"; then
  fail "installer references the old OMARCHY_PATH variable"
fi
pass "installer speaks MAGIKOS_PATH only"

# The skeleton must be assembled the way the magikos-settings package would:
# config/** under .config, bashrc as a dotfile, not a flat default/ dump.
grep -q 'skel/.config' "$installer" || fail "assembles skel .config from config/"
grep -q 'skel/.bashrc' "$installer" || fail "installs default/bashrc as skel .bashrc"
if grep -q 'cp -a "$ROOT/default/." ' "$installer"; then
  fail "no flat default/ copy into skel remains"
fi
pass "skeleton assembly follows the build-time map"

pass "installer smoke tests complete"
