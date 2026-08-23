#!/bin/bash

source "$(dirname "${BASH_SOURCE[0]}")/base-test.sh"

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

home="$tmpdir/home"
magikos_path="$tmpdir/magikos"

mkdir -p "$home/.config/sway" "$magikos_path/config/sway"

cat >"$magikos_path/config/sway/bindings.conf" <<'EOF'
-- refreshed from MAGIKOS_PATH
EOF

cat >"$home/.config/sway/bindings.conf" <<'EOF'
-- existing user config
EOF

HOME="$home" MAGIKOS_PATH="$magikos_path" "$ROOT/bin/magikos-refresh-config" sway/bindings.conf >/dev/null

cmp -s "$magikos_path/config/sway/bindings.conf" "$home/.config/sway/bindings.conf" ||
  fail "refresh-config copies from MAGIKOS_PATH/config"

backup=$(find "$home/.config/sway" -name 'bindings.conf.bak.*' -print -quit)
[[ -n $backup ]] || fail "refresh-config backs up replaced user config"
grep -Fq -- '-- existing user config' "$backup" ||
  fail "refresh-config backup contains previous user config"

pass "refresh-config copies from MAGIKOS_PATH/config and backs up existing files"

if HOME="$home" MAGIKOS_PATH="$magikos_path" "$ROOT/bin/magikos-refresh-config" sway/missing.conf >"$tmpdir/out" 2>"$tmpdir/err"; then
  fail "refresh-config rejects configs missing from MAGIKOS_PATH/config"
fi

grep -Fq 'Not a shipped user config: sway/missing.conf' "$tmpdir/err" ||
  fail "refresh-config reports missing shipped config"

pass "refresh-config validates against MAGIKOS_PATH/config"
