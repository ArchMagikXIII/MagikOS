#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

test_tmp=$(mktemp -d)
trap 'rm -rf "$test_tmp"' EXIT

mock_bin="$test_tmp/bin"
mkdir -p "$mock_bin"

cat >"$mock_bin/magikos-cmd-present" <<'SH'
#!/bin/bash
[[ ${MAGIKOS_TEST_INSTALLED:-false} == "true" ]]
SH

cat >"$mock_bin/setsid" <<'SH'
#!/bin/bash
shift
printf 'launch:%s\n' "$*" >"$MAGIKOS_TEST_LOG"
SH

cat >"$mock_bin/magikos-launch-floating-terminal-with-presentation" <<'SH'
#!/bin/bash
printf 'install:%s\n' "$*" >"$MAGIKOS_TEST_LOG"
SH

chmod +x "$mock_bin"/*

launch_log="$test_tmp/launch-log"
PATH="$mock_bin:$PATH" MAGIKOS_TEST_INSTALLED=true MAGIKOS_TEST_LOG="$launch_log" \
  bash "$ROOT/bin/magikos-launch-1password"
grep -Fxq 'launch:-- 1password' "$launch_log" || fail "1Password launcher starts the installed app"
pass "1Password launcher starts the installed app"

PATH="$mock_bin:$PATH" MAGIKOS_TEST_INSTALLED=false MAGIKOS_TEST_LOG="$launch_log" \
  bash "$ROOT/bin/magikos-launch-1password"
grep -Fxq 'install:magikos-install-service-1password' "$launch_log" ||
  fail "1Password launcher starts the installer when missing"
pass "1Password launcher starts the installer when missing"
