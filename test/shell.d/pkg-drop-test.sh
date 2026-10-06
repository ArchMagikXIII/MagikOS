#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

test_tmp=$(mktemp -d)
trap 'rm -rf "$test_tmp"' EXIT

mock_path="$test_tmp/pkg-drop-bin"
mkdir -p "$mock_path"

cat >"$mock_path/pacman" <<'EOF'
#!/bin/bash
if [[ $1 == "-Qq" ]]; then
  printf '%s\n' exact-package provider-package
fi
EOF

cat >"$mock_path/sudo" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >"$TEST_TMP/pkg-drop-command"
EOF

chmod +x "$mock_path/pacman" "$mock_path/sudo"

PATH="$mock_path:$ROOT/bin:$PATH" TEST_TMP="$test_tmp" \
  "$ROOT/bin/magikos-pkg-drop" exact-package virtual-package provider-package exact-package

[[ $(<"$test_tmp/pkg-drop-command") == "pacman -Rns --noconfirm exact-package provider-package" ]] ||
  fail "package removal targets exact installed names only"
# -Rns already collects orphans, so a second transaction would be redundant.
[[ $(wc -l <"$test_tmp/pkg-drop-command") == "1" ]] ||
  fail "pacman removal should not issue a separate autoremove pass"
pass "package removal ignores providers and duplicate arguments"

# --- apt: purge and autoremove are two verbs, so two transactions ---

apt_path="$test_tmp/pkg-drop-apt-bin"
mkdir -p "$apt_path"

cat >"$apt_path/dpkg-query" <<'EOF'
#!/bin/bash
printf 'exact-package\tinstalled\nprovider-package\tinstalled\n'
EOF

cat >"$apt_path/sudo" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >>"$TEST_TMP/pkg-drop-apt-commands"
EOF

chmod +x "$apt_path/dpkg-query" "$apt_path/sudo"

PATH="$apt_path:$ROOT/bin:$PATH" TEST_TMP="$test_tmp" MAGIKOS_PKG_BACKEND=apt \
  "$ROOT/bin/magikos-pkg-drop" exact-package virtual-package provider-package

mapfile -t apt_commands <"$test_tmp/pkg-drop-apt-commands"
[[ ${apt_commands[0]} == "env DEBIAN_FRONTEND=noninteractive apt-get purge -y exact-package provider-package" ]] ||
  fail "apt removal purges the exact installed names" "got: ${apt_commands[0]:-<none>}"
[[ ${apt_commands[1]} == "env DEBIAN_FRONTEND=noninteractive apt-get autoremove -y" ]] ||
  fail "apt removal sweeps orphaned dependencies afterwards" "got: ${apt_commands[1]:-<none>}"
[[ $(wc -l <"$test_tmp/pkg-drop-apt-commands") == "2" ]] ||
  fail "apt removal should issue exactly the purge and autoremove passes"
pass "apt removal purges then autoremoves"
