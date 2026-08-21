#!/bin/bash

set -euo pipefail

source "$(dirname "$0")/base-test.sh"

test_tmp=$(mktemp -d)
trap 'rm -rf "$test_tmp"' EXIT

run_guard() {
  MAGIKOS_PACMAN_CMDLINE="$1" "$ROOT/bin/magikos-update-pacman-guard"
}

if run_guard "pacman -Syu --noconfirm" >"$test_tmp/direct.out" 2>"$test_tmp/direct.err"; then
  fail "pacman guard blocks direct system upgrades"
fi
grep -q 'magikos update' "$test_tmp/direct.err" || fail "pacman guard explains magikos update entrypoint"
pass "pacman guard blocks direct pacman -Syu"

if run_guard "pacman --sync --refresh --sysupgrade" >"$test_tmp/long.out" 2>"$test_tmp/long.err"; then
  fail "pacman guard blocks long-form system upgrades"
fi
pass "pacman guard blocks long-form pacman sysupgrade"

MAGIKOS_UPDATE_PACMAN=1 run_guard "pacman -Syu --noconfirm" >"$test_tmp/magikos.out" 2>"$test_tmp/magikos.err"
[[ ! -s $test_tmp/magikos.err ]] || fail "pacman guard stays quiet for magikos update pacman call"
pass "pacman guard allows magikos update pacman call"

MAGIKOS_ALLOW_DIRECT_PACMAN=1 run_guard "pacman -Syu --noconfirm" >"$test_tmp/override.out" 2>"$test_tmp/override.err"
[[ ! -s $test_tmp/override.err ]] || fail "pacman guard stays quiet for explicit direct pacman override"
pass "pacman guard allows explicit direct pacman override"

run_guard "pacman -S firefox" >"$test_tmp/install.out" 2>"$test_tmp/install.err"
[[ ! -s $test_tmp/install.err ]] || fail "pacman guard stays quiet for non-sysupgrade pacman command"
pass "pacman guard ignores non-system-upgrade transactions"
