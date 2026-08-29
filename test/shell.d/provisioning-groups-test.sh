#!/bin/bash
#
# The install scripts that grant group memberships must record them in the provisioning
# groups file (for first-boot user creation and factory reset) and only call
# usermod when the install user actually exists.

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

export MAGIKOS_PROVISIONING_DIR="$TMPDIR/provisioning"

# Stub getent/usermod: the fake system knows only the user "existing".
mkdir -p "$TMPDIR/bin"
cat >"$TMPDIR/bin/getent" <<'EOF'
#!/bin/bash
[[ $1 == passwd && $2 == existing ]] && { echo "existing:x:1000:1000::/home/existing:/bin/bash"; exit 0; }
exit 2
EOF
cat >"$TMPDIR/bin/usermod" <<EOF
#!/bin/bash
echo "\$@" >>"$TMPDIR/usermod.calls"
EOF
chmod +x "$TMPDIR/bin/getent" "$TMPDIR/bin/usermod"
export PATH="$TMPDIR/bin:$PATH"

# No install user (deferred-provisioning install): groups recorded, usermod not called.
MAGIKOS_INSTALL_USER="" bash -eE "$ROOT/install/hardware/input-group.sh"

[[ -f $MAGIKOS_PROVISIONING_DIR/groups ]] || fail "groups file written without an install user"
grep -qxF input "$MAGIKOS_PROVISIONING_DIR/groups" || fail "input group recorded"
[[ ! -f $TMPDIR/usermod.calls ]] || fail "usermod not called without an install user"
pass "deferred provisioning records groups without calling usermod"

# Missing user (defensive): no usermod either.
MAGIKOS_INSTALL_USER=ghost bash -eE "$ROOT/install/hardware/input-group.sh"
[[ ! -f $TMPDIR/usermod.calls ]] || fail "usermod not called for a missing user"
pass "missing install user defers group grants"

# Re-running never duplicates entries.
MAGIKOS_INSTALL_USER="" bash -eE "$ROOT/install/hardware/input-group.sh"
[[ $(grep -cxF input "$MAGIKOS_PROVISIONING_DIR/groups") == 1 ]] || fail "input group recorded once"
pass "group recording is idempotent"

# Existing user: usermod applies the groups and the record still lands.
MAGIKOS_INSTALL_USER=existing bash -eE "$ROOT/install/hardware/input-group.sh"
grep -qx -- "-aG input existing" "$TMPDIR/usermod.calls" || fail "usermod grants input to the install user"
pass "existing install user still gets direct group grants"
