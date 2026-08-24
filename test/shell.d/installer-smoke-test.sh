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

# --- dnf.map: every mapping must name a real entry in the base package list ---

map_file="$ROOT/installer/dnf.map"
package_list="$ROOT/install/magikos-base.packages"

while IFS= read -r line; do
  arch=${line%%|*}
  specs=${line#*|}
  if [[ $arch == "$line" || -z $specs ]]; then
    fail "dnf.map line is well-formed: $line"
  fi
  if ! grep -qx "$arch" "$package_list"; then
    fail "dnf.map maps a name that is not in the base list: $arch" "$line"
  fi
done < <(grep -vE '^[[:space:]]*(#|$)' "$map_file")
pass "dnf.map entries are well-formed and grounded in the base list"

# Names mapped away must not be the whole story on Arch: the pacman path has
# no exclusions, so only a plausible subset of the base list may be skipped.
skipped=()
while read -r pkg; do
  [[ -n $pkg ]] || continue
  if grep -qFx "$pkg|-" "$map_file"; then
    skipped+=("$pkg")
  fi
done < <(grep -v '^#' "$package_list" | grep -v '^$')
if ((${#skipped[@]} > 60)); then
  fail "dnf.map skips an implausible number of packages (${#skipped[@]})"
fi
pass "dnf.map skips a plausible subset (${#skipped[@]} of $(grep -cv -e '^#' -e '^$' "$package_list"))"

pass "installer smoke tests complete"
