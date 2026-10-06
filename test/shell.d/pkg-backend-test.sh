#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

test_tmp=$(mktemp -d)
trap 'rm -rf "$test_tmp"' EXIT

# --- Detection resolves from whatever is actually installed ---

detected=$(bash -c 'source "$ROOT/bin/magikos-pkg-backend" && echo "$MAGIKOS_PKG_BACKEND"' || true)
if command -v pacman >/dev/null 2>&1; then
  [[ $detected == pacman ]] || fail "default backend resolves to pacman (got: $detected)"
  pass "backend resolves to pacman by default"
elif command -v apt-get >/dev/null 2>&1; then
  [[ $detected == apt ]] || fail "default backend resolves to apt (got: $detected)"
  pass "backend resolves to apt by default"
else
  fail "no supported package manager is installed"
fi

# --- Predicates agree with the resolved backend ---

# `|| true` matters: a compound `backend_is_pacman && echo yes` returns
# non-zero whenever the predicate is false, and under set -e that propagates
# out of the assignment and kills the suite before it can report anything.
pacman_predicate=$(bash -c 'source "$ROOT/bin/magikos-pkg-backend" && backend_is_pacman && echo yes' || true)
apt_predicate=$(bash -c 'source "$ROOT/bin/magikos-pkg-backend" && backend_is_apt && echo yes' || true)

if [[ $detected == pacman ]]; then
  [[ $pacman_predicate == yes ]] || fail "backend_is_pacman reports pacman when the backend is pacman"
  [[ -z $apt_predicate ]] || fail "backend_is_apt is false when the backend is pacman"
else
  [[ -z $pacman_predicate ]] || fail "backend_is_pacman is false when the backend is apt"
  [[ $apt_predicate == yes ]] || fail "backend_is_apt reports apt when the backend is apt"
fi
pass "backend_is_pacman and backend_is_apt agree with the resolved backend ($detected)"

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

# The backend is forced rather than left to detection: this asserts the pacman
# shape on every host, including the Debian one that would otherwise resolve
# to apt and never reach these functions.
TEST_TMP="$test_tmp" MAGIKOS_PKG_BACKEND=pacman PATH="$test_tmp/query-bin:/usr/bin:/bin" bash -c '
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

cmds=$(bash -c 'MAGIKOS_PKG_BACKEND=pacman; source "$ROOT/bin/magikos-pkg-backend"; printf "%s\n%s\n%s\n%s\n%s\n" "${PKG_INSTALL_CMD[*]}" "${PKG_REMOVE_CMD[*]}" "${PKG_AUTOREMOVE_CMD[*]}" "${PKG_UPGRADE_CMD[*]}" "${PKG_SYNC_CMD[*]}"')
[[ $(sed -n '1p' <<<"$cmds") == "pacman -S --noconfirm --needed" ]] || fail "pacman install shape changed"
[[ $(sed -n '2p' <<<"$cmds") == "pacman -Rns --noconfirm" ]] || fail "pacman remove shape changed"
# -Rns already collects orphaned dependencies, so pacman has nothing left for a
# separate autoremove pass; the array exists for backends that need one.
[[ -z $(sed -n '3p' <<<"$cmds") ]] || fail "pacman should not need a separate autoremove pass"
[[ $(sed -n '4p' <<<"$cmds") == "env MAGIKOS_UPDATE_PACMAN=1 pacman -Syu --noconfirm" ]] || fail "pacman upgrade shape changed"
[[ $(sed -n '5p' <<<"$cmds") == "env MAGIKOS_UPDATE_PACMAN=1 pacman -Syyuu --noconfirm" ]] || fail "pacman sync shape changed"
pass "pacman keeps its install/remove/upgrade/sync shapes with the update guard"

# --- Privileged transaction shapes on apt ---

apt_cmds=$(bash -c 'MAGIKOS_PKG_BACKEND=apt; source "$ROOT/bin/magikos-pkg-backend"; printf "%s\n%s\n%s\n%s\n%s\n" "${PKG_INSTALL_CMD[*]}" "${PKG_REMOVE_CMD[*]}" "${PKG_AUTOREMOVE_CMD[*]}" "${PKG_UPGRADE_CMD[*]}" "${PKG_SYNC_CMD[*]}"')
[[ $(sed -n '1p' <<<"$apt_cmds") == "env DEBIAN_FRONTEND=noninteractive apt-get install -y" ]] ||
  fail "apt install shape changed"
# apt cannot purge and sweep orphans in one verb, so removal and autoremove
# are separate arrays here and magikos-pkg-drop runs both in order.
[[ $(sed -n '2p' <<<"$apt_cmds") == "env DEBIAN_FRONTEND=noninteractive apt-get purge -y" ]] ||
  fail "apt remove shape changed"
[[ $(sed -n '3p' <<<"$apt_cmds") == "env DEBIAN_FRONTEND=noninteractive apt-get autoremove -y" ]] ||
  fail "apt autoremove shape changed"
[[ $(sed -n '4p' <<<"$apt_cmds") == "env DEBIAN_FRONTEND=noninteractive apt-get upgrade -y" ]] ||
  fail "apt upgrade shape changed"
[[ $(sed -n '5p' <<<"$apt_cmds") == "env DEBIAN_FRONTEND=noninteractive apt-get update" ]] ||
  fail "apt sync shape changed"
pass "apt maps install/remove/autoremove/upgrade/sync onto apt-get"

# --- apt resolves package names and virtual Provides the way pacman does ---

mkdir -p "$test_tmp/dpkg-bin"
cat >"$test_tmp/dpkg-bin/dpkg-query" <<'EOF'
#!/bin/bash
# Field order matches the backend's format string: name, Provides, status.
cat <<'DATA'
alpha	alpha-alias	installed
beta		installed
gamma		not-installed
delta	delta-exact (= 1.2-1), delta-arch [amd64]	installed
DATA
EOF
chmod +x "$test_tmp/dpkg-bin/dpkg-query"

# pkg_installed returns 0 only when *every* named package resolves, so probe it
# through a helper that reports rather than tripping set -e on the failures.
apt_probe() {
  TEST_TMP="$test_tmp" MAGIKOS_PKG_BACKEND=apt PATH="$test_tmp/dpkg-bin:/usr/bin:/bin" bash -c '
    source "$ROOT/bin/magikos-pkg-backend"
    pkg_installed "$@" >/dev/null 2>&1
  ' _ "$@" && echo yes || echo no
}

[[ $(apt_probe alpha) == yes ]] || fail "apt pkg_installed finds an installed package"
[[ $(apt_probe beta) == yes ]] || fail "apt pkg_installed finds an installed package with no Provides"
[[ $(apt_probe gamma) == no ]] || fail "apt pkg_installed rejects a package that is not installed"
[[ $(apt_probe alpha beta) == yes ]] || fail "apt pkg_installed accepts several installed packages"
[[ $(apt_probe alpha gamma) == no ]] || fail "apt pkg_installed rejects the set when one package is missing"
# dpkg reports virtual names through Provides, and callers rely on those
# answering yes exactly as they do under pacman.
[[ $(apt_probe alpha-alias) == yes ]] || fail "apt pkg_installed resolves a Provides name"
[[ $(apt_probe delta-exact) == yes ]] || fail "apt pkg_installed strips the version constraint from Provides"
[[ $(apt_probe delta-arch) == yes ]] || fail "apt pkg_installed strips the architecture qualifier from Provides"
[[ $(apt_probe no-such-package) == no ]] || fail "apt pkg_installed rejects an unknown name"
# No arguments means "nothing to be missing", which the menu guards rely on.
[[ $(apt_probe) == yes ]] || fail "apt pkg_installed with no arguments is true"
pass "apt pkg_installed resolves names, virtual Provides, and multi-package sets"

# --- pkg_list_installed drops packages dpkg has only config files for ---

mkdir -p "$test_tmp/list-bin"
cat >"$test_tmp/list-bin/dpkg-query" <<'EOF'
#!/bin/bash
# Two fields, matching the format pkg_list_installed asks for: name, status.
printf 'kept\tinstalled\nleftover\tdeinstall\n'
EOF
chmod +x "$test_tmp/list-bin/dpkg-query"

listed=$(TEST_TMP="$test_tmp" MAGIKOS_PKG_BACKEND=apt PATH="$test_tmp/list-bin:/usr/bin:/bin" bash -c '
  source "$ROOT/bin/magikos-pkg-backend"
  pkg_list_installed
')
[[ $listed == kept ]] || fail "apt pkg_list_installed lists only installed packages" "got: $listed"
pass "apt pkg_list_installed excludes config-files-only packages"