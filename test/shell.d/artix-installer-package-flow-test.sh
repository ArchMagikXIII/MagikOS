#!/bin/bash
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/base-test.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export TEST_LOG="$tmp/pacman.log" ARTIX_MANIFEST="$ROOT/install/magikos-base-artix-openrc.packages"
mkdir -p "$tmp/bin"
cat >"$tmp/bin/pacman-conf" <<'STUB'
#!/bin/bash
printf 'system\nworld\ngalaxy\nlib32\n'
STUB
cat >"$tmp/bin/pacman" <<'STUB'
#!/bin/bash
case $1 in
  -Slq) grep -vE '^[[:space:]]*(#|$)' "$ARTIX_MANIFEST" | grep -Fxv "${ARTIX_MISSING:-NONEXISTENT}" ;;
  -Q) exit 1 ;;
  -S) printf '%s\n' "$*" >>"$TEST_LOG"; [[ ${ARTIX_TRANSACTION_FAIL:-0} != 1 ]] ;;
  *) exit 2 ;;
esac
STUB
chmod +x "$tmp/bin/"*
export PATH="$tmp/bin:$PATH"

installer="$ROOT/installer/magikos-install"
source <(sed -n '/^artix_package_names() {/,/^}/p' "$installer")
source <(sed -n '/^check_artix_packages() {/,/^}/p' "$installer")
source <(sed -n '/^install_packages_host() {/,/^}/p' "$installer")
log() { :; }
die() { printf '%s\n' "$1" >&2; return 1; }
run() { "$@"; }
ARTIX_OPENRC=1 DRY_RUN=0

check_artix_packages || fail "all curated packages are found in Artix repositories"
if ARTIX_MISSING=quickshell check_artix_packages 2>"$tmp/error"; then
  fail "missing core Artix package aborts before installation"
fi
grep -q quickshell "$tmp/error" || fail "preflight names the unavailable package"
[[ ! -e $TEST_LOG ]] || fail "preflight never runs pacman -S"
pass "Artix preflight rejects missing repo packages without modifying the host"

install_packages_host || fail "Artix transaction succeeds with available packages"
grep -q '^-S --needed ' "$TEST_LOG" || fail "Artix uses the conservative pacman transaction"
! grep -Eq -- '--(noconfirm|ask|overwrite)' "$TEST_LOG" || fail "Artix must not auto-remove conflicts or overwrite host files"
! grep -Eq 'cachyos|linux-omarchy|uwsm' "$TEST_LOG" || fail "Artix manifest must not pull incompatible packages"
pass "Artix package install avoids AUR, kernel replacement, forced removals and overwrites"

if ARTIX_TRANSACTION_FAIL=1 install_packages_host >/dev/null 2>"$tmp/error"; then
  fail "failed Artix repo transaction must stop installation"
fi
pass "Artix transaction failure is fatal"
