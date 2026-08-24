#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

run_node_test <<'JS'
const nightlight = requireFromRoot('shell/plugins/services/nightlight/NightlightModel.js')

assertEqual(nightlight.temperatureFromOutput('4000\n'), 4000, 'nightlight parses probe temperature')
assertEqual(nightlight.temperatureFromOutput('no daemon running'), null, 'nightlight treats digitless probe output as unknown')
assertEqual(nightlight.isNightlight(4000), true, 'nightlight reports warm temperatures as enabled')
assertEqual(nightlight.isNightlight(5999), true, 'nightlight reports warmer-than-identity values as enabled')
assertEqual(nightlight.isNightlight(6000), false, 'nightlight reports identity temperature as disabled')
assertEqual(nightlight.isNightlight(null), false, 'nightlight reports unknown temperature as disabled')
JS

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

mkdir -p "$TMPDIR/bin"
STATE="$TMPDIR/wlsunset-temp"
SHELL_LOG="$TMPDIR/magikos-shell-log"

# The fake daemon state doubles as the running process's cmdline: pgrep -ax
# reports it the way the real one would for `wlsunset -t X -T X`.
cat >"$TMPDIR/bin/pgrep" <<'SH'
#!/bin/bash
[[ -r $WLSUNSET_STATE ]] || exit 1
temp=$(cat "$WLSUNSET_STATE")
printf '4242 wlsunset -t %s -T %s\n' "$temp" "$temp"
SH

cat >"$TMPDIR/bin/pkill" <<'SH'
#!/bin/bash
rm -f "$WLSUNSET_STATE"
SH

cat >"$TMPDIR/bin/uwsm-app" <<'SH'
#!/bin/bash
prev=""
for arg in "$@"; do
  if [[ $prev == "-t" ]]; then
    printf '%s\n' "$arg" >"$WLSUNSET_STATE"
  fi
  prev=$arg
done
SH

cat >"$TMPDIR/bin/magikos-shell" <<'SH'
#!/bin/bash
printf '%s\n' "$*" >>"$MAGIKOS_SHELL_LOG"
SH

chmod +x "$TMPDIR/bin/pgrep" "$TMPDIR/bin/pkill" "$TMPDIR/bin/uwsm-app" "$TMPDIR/bin/magikos-shell"

nightlight_cli() {
  PATH="$TMPDIR/bin:$PATH" \
  WLSUNSET_STATE="$STATE" \
  MAGIKOS_SHELL_LOG="$SHELL_LOG" \
    "$ROOT/bin/magikos-toggle-nightlight" "$@"
}

nightlight_status() {
  printf '%s\n' "$1" >"$STATE"
  nightlight_cli --status
}

[[ $(nightlight_status 4000 | jq -r .enabled) == "true" ]] || fail "nightlight status reports 4000K as enabled"
pass "nightlight status reports 4000K as enabled"

[[ $(nightlight_status 5999 | jq -r .enabled) == "true" ]] || fail "nightlight status reports warmer-than-identity values as enabled"
pass "nightlight status reports warmer-than-identity values as enabled"

[[ $(nightlight_status 6000 | jq -r .enabled) == "false" ]] || fail "nightlight status reports identity temperature as disabled"
pass "nightlight status reports identity temperature as disabled"

[[ $(nightlight_status 6500 | jq -r .enabled) == "false" ]] || fail "nightlight status reports daylight temperature as disabled"
pass "nightlight status reports daylight temperature as disabled"

printf '6500\n' >"$STATE"
: >"$SHELL_LOG"
nightlight_cli >/dev/null
[[ $(<"$STATE") == 4000 ]] || fail "nightlight toggle warms the screen from daylight"
pass "nightlight toggle warms the screen from daylight"

grep -Fqx -- '-q nightlight refresh' "$SHELL_LOG" || fail "nightlight toggle nudges the shell nightlight service"
pass "nightlight toggle nudges the shell nightlight service"

nightlight_cli >/dev/null
[[ ! -e $STATE ]] || fail "nightlight toggle restores daylight from night light"
pass "nightlight toggle restores daylight from night light"

if rg -q 'magikos.indicators' "$ROOT/bin/magikos-toggle-nightlight"; then
  fail "nightlight toggle leaves indicator refresh to the nightlight service"
fi
pass "nightlight toggle leaves indicator refresh to the nightlight service"
