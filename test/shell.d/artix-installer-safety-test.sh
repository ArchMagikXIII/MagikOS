#!/bin/bash
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/base-test.sh"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin"
printf 'NAME="Artix Linux"\nID=artix\n' >"$tmp/artix-release"
printf 'NAME="Arch Linux"\nID=arch\n' >"$tmp/arch-release"

source "$ROOT/install/helpers/platform.sh"
MAGIKOS_OS_RELEASE="$tmp/artix-release" magikos_is_artix || fail "Artix is detected by os-release"
if MAGIKOS_OS_RELEASE="$tmp/arch-release" magikos_is_artix; then
  fail "Arch is not mistaken for Artix"
fi
pass "platform detection distinguishes Artix from Arch"

cat >"$tmp/bin/cp" <<'STUB'
#!/bin/bash
printf 'cp %s\n' "$*" >>"$TEST_LOG"
STUB
cat >"$tmp/bin/lspci" <<'STUB'
#!/bin/bash
exit 0
STUB
cat >"$tmp/bin/sudo" <<'STUB'
#!/bin/bash
printf 'sudo %s\n' "$*" >>"$TEST_LOG"
STUB
chmod +x "$tmp/bin/"*
export PATH="$ROOT/bin:$tmp/bin:$PATH"
export MAGIKOS_PATH="$ROOT" MAGIKOS_INSTALL="$ROOT/install" MAGIKOS_PKG_BACKEND=pacman
export TEST_LOG="$tmp/calls"

MAGIKOS_OS_RELEASE="$tmp/artix-release" bash -eE -c 'source "$MAGIKOS_INSTALL/post-install/pacman.sh"' >"$tmp/out"
grep -Fq 'preserving existing pacman.conf' "$tmp/out" || fail "post-install reports preservation of Artix repositories"
[[ ! -e $TEST_LOG ]] || fail "post-install never copies Arch pacman files onto Artix"
pass "post-install preserves Artix pacman.conf and mirrorlist"

MAGIKOS_OS_RELEASE="$tmp/arch-release" bash -eE -c 'source "$MAGIKOS_INSTALL/post-install/pacman.sh"' >"$tmp/out"
grep -q 'pacman-stable.conf /etc/pacman.conf' "$TEST_LOG" || fail "post-install retains the Arch behavior"
grep -q 'mirrorlist-stable /etc/pacman.d/mirrorlist' "$TEST_LOG" || fail "post-install retains Arch mirrorlist behavior"
pass "post-install still restores Arch pacman configuration"

: >"$TEST_LOG"
if MAGIKOS_OS_RELEASE="$tmp/artix-release" bash "$ROOT/bin/magikos-refresh-pacman" >"$tmp/out" 2>&1; then
  fail "pacman refresh refuses Artix's incompatible Arch template"
fi
[[ ! -s $TEST_LOG ]] || fail "pacman refresh did not touch Artix repositories"
grep -Fq "Leaving Artix's pacman.conf and mirrorlist untouched" "$tmp/out" || fail "pacman refresh explains why it refuses Artix"
pass "pacman refresh fails safely before copying files on Artix"

# The leaf scripts are sourced through MAGIKOS_INSTALL, which already ends in
# /install. Confirm the checked-in helper resolves there, not /install/install.
MAGIKOS_NO_SYSTEMD=1 MAGIKOS_NO_OPENRC=1 MAGIKOS_NO_RUNIT=1 \
  MAGIKOS_INSTALL="$ROOT/install" bash -eE -c \
  'source "${MAGIKOS_INSTALL}/helpers/systemd.sh"; ! magikos_service_is_active nonexistent'
pass "init helper is accessible and unknown init does not report a running service"

# Regression for the Artix VM failure: the snapper leaf used to resolve the
# helper as /usr/share/magikos/install/install/helpers/systemd.sh.
cat >"$tmp/bin/snapper" <<'STUB'
#!/bin/bash
exit 0
STUB
chmod +x "$tmp/bin/snapper"
MAGIKOS_NO_SYSTEMD=1 MAGIKOS_NO_OPENRC=1 MAGIKOS_NO_RUNIT=1 \
MAGIKOS_SNAPPER_CONFIGURE_TEST=1 \
MAGIKOS_SNAPPER_CONFIG_PATH="$tmp/snapper/root" \
MAGIKOS_SNAPPER_CONF_PATH="$tmp/conf.d/snapper" \
  bash -eE "$ROOT/install/config/snapper.sh" >"$tmp/snapper.out"
cmp -s "$ROOT/default/snapper/root" "$tmp/snapper/root" || fail "snapper leaf completes with the correct helper path"
pass "snapper leaf resolves the helper with one install directory"

# Existing-mode failures must not print a success banner and exit zero.
source <(sed -n '/^finish_existing() {/,/^}/p' "$ROOT/installer/magikos-install")
log() { :; }
warn() { :; }
report_pkg_failures() { :; }
INSTALL_USER=tester LOG_FILE="$tmp/install.log" MAGIKOS_INSTALL_LOG_FILE="" ARTIX_OPENRC=0
PKG_FAILURES=(missing-package)
INSTALL_ERRORS=()
if finish_existing; then fail "missing packages make adoption fail"; fi
PKG_FAILURES=()
INSTALL_ERRORS=("system setup")
if finish_existing; then fail "failed system setup makes adoption fail"; fi
INSTALL_ERRORS=()
finish_existing || fail "complete adoption still succeeds"
pass "adoption reports nonzero status on missing packages or failed setup"
