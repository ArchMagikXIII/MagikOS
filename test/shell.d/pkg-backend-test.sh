#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

test_tmp=$(mktemp -d)
trap 'rm -rf "$test_tmp"' EXIT

# --- Detection: pacman-only; resolves to pacman when MAGIKOS_PKG_BACKEND is unset ---

if command -v pacman >/dev/null 2>&1; then
  backend=$(bash -c 'source "$ROOT/bin/magikos-pkg-backend" && echo "$MAGIKOS_PKG_BACKEND"')
  [[ $backend == pacman ]] || fail "default backend resolves to pacman (got: $backend)"
  pass "backend resolves to pacman by default"
fi

backend_is_pacman_result=$(bash -c 'source "$ROOT/bin/magikos-pkg-backend" && backend_is_pacman && echo yes')
[[ $backend_is_pacman_result == yes ]] || fail "backend_is_pacman is always true"
pass "backend_is_pacman reports pacman"

# --- Queries speak pacman ---

mkdir -p "$test_tmp/query-bin"
cat >"$test_tmp/query-bin/pacman" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >>"$TEST_TMP/pacman-calls"
if [[ $1 == "-Q" ]]; then
  exit 0
fi
EOF
chmod +x "$test_tmp/query-bin/pacman"

TEST_TMP="$test_tmp" PATH="$test_tmp/query-bin:/usr/bin:/bin" bash -c '
  source "$ROOT/bin/magikos-pkg-backend"
  pkg_installed firefox >/dev/null
  pkg_list_installed >/dev/null
' 
grep -q -- "-Q firefox" "$test_tmp/pacman-calls" ||
  fail "pkg_installed calls pacman -Q"
grep -q -- "-Qq" "$test_tmp/pacman-calls" ||
  fail "pkg_list_installed calls pacman -Qq"
pass "pkg_installed and pkg_list_installed speak pacman"

# --- Privileged transaction shapes stay pacman ---

cmds=$(bash -c 'source "$ROOT/bin/magikos-pkg-backend"; printf "%s\n%s\n%s\n%s\n" "${PKG_INSTALL_CMD[*]}" "${PKG_REMOVE_CMD[*]}" "${PKG_UPGRADE_CMD[*]}" "${PKG_SYNC_CMD[*]}"')
[[ $(sed -n '1p' <<<"$cmds") == "pacman -S --noconfirm --needed" ]] || fail "pacman install shape changed"
[[ $(sed -n '2p' <<<"$cmds") == "pacman -Rns --noconfirm" ]] || fail "pacman remove shape changed"
[[ $(sed -n '3p' <<<"$cmds") == "env MAGIKOS_UPDATE_PACMAN=1 pacman -Syu --noconfirm" ]] || fail "pacman upgrade shape changed"
[[ $(sed -n '4p' <<<"$cmds") == "env MAGIKOS_UPDATE_PACMAN=1 pacman -Syyuu --noconfirm" ]] || fail "pacman sync shape changed"
pass "pacman keeps its install/remove/upgrade/sync shapes with the update guard"
