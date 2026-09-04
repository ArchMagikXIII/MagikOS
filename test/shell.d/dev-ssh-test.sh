#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

require_command git
require_command ssh-keygen

make_tmpdir() {
  local -n dir_ref=$1
  dir_ref=$(mktemp -d)
}

make_tmpdir TEST_DIR
mkdir -p "$TEST_DIR/home" "$TEST_DIR/checkout"
chmod 700 "$TEST_DIR/home"

git -C "$TEST_DIR/checkout" init -q
git -C "$TEST_DIR/checkout" config user.email "dev@example.com"
git -C "$TEST_DIR/checkout" remote add origin https://github.com/example/MagikOS.git

(cd "$TEST_DIR/checkout" && HOME="$TEST_DIR/home" "$ROOT/bin/magikos-dev-ssh" --remote=origin >"$TEST_DIR/out" 2>&1)

[[ -f "$TEST_DIR/home/.ssh/id_ed25519" ]] || fail "magikos-dev-ssh generates an ed25519 key when none exists"
[[ -f "$TEST_DIR/home/.ssh/id_ed25519.pub" ]] || fail "magikos-dev-ssh generates the matching public key"
pass "magikos-dev-ssh generates an ed25519 key when none exists"
pass "magikos-dev-ssh generates the matching public key"

grep -q 'dev@example.com' "$TEST_DIR/home/.ssh/id_ed25519.pub" || fail "magikos-dev-ssh comments the key with the repo's git user email"
pass "magikos-dev-ssh comments the key with the repo's git user email"

remote_url=$(git -C "$TEST_DIR/checkout" config remote.origin.url)
[[ $remote_url == "git@github.com:example/MagikOS.git" ]] || fail "magikos-dev-ssh rewrites an HTTPS origin to the SSH form"
pass "magikos-dev-ssh rewrites an HTTPS origin to the SSH form"

(cd "$TEST_DIR/checkout" && HOME="$TEST_DIR/home" "$ROOT/bin/magikos-dev-ssh" --remote=origin >"$TEST_DIR/out2" 2>&1)
grep -q 'already uses SSH: git@github.com:example/MagikOS.git' "$TEST_DIR/out2" || fail "magikos-dev-ssh is idempotent on a second run over an SSH remote"
remote_url2=$(git -C "$TEST_DIR/checkout" config remote.origin.url)
[[ $remote_url2 == "git@github.com:example/MagikOS.git" ]] || fail "magikos-dev-ssh leaves an already-SSH remote unchanged"
pass "magikos-dev-ssh is idempotent on a second run over an SSH remote"
pass "magikos-dev-ssh leaves an already-SSH remote unchanged"

rm -rf "$TEST_DIR"
