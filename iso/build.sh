#!/bin/bash
# Build the MagikOS live installer ISO.
#
# The ISO is the stock archiso `releng` profile with the MagikOS overlay in
# iso/profile/ on top: rebranded identity, a minimal live package set (just
# enough to run installer/magikos-install against the Arch/CachyOS repos), and
# the repo tree bundled at /root/magikos so a fresh boot is one command away
# from an install.
#
# Requirements: root, the `archiso` package (provides releng + mkarchiso),
# `squashfs-tools` (airootfs image), and `rsync` (profile overlay).
#
# Usage:
#   ./iso/build.sh [-o OUT_DIR] [--extra-overlay DIR] [--boot-console DEV]
set -euo pipefail

REPO="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RELENG=${RELENG:-/usr/share/archiso/configs/releng}

OUT_DIR="$REPO/iso/release"
EXTRA_OVERLAY=()
BOOT_CONSOLE=

while (( $# > 0 )); do
  case $1 in
    -o|--out-dir) OUT_DIR=$2; shift 2 ;;
    --extra-overlay) EXTRA_OVERLAY+=("$2"); shift 2 ;;
    --boot-console) BOOT_CONSOLE=$2; shift 2 ;;
    -h|--help)
      sed -n '7,16p' "${BASH_SOURCE[0]}"
      exit 0
      ;;
    *) echo "unknown argument: $1" >&2; exit 1 ;;
  esac
done

[[ $(id -u) == 0 ]] || { echo "iso/build.sh must run as root" >&2; exit 1; }
command -v rsync >/dev/null || { echo "rsync is required" >&2; exit 1; }
command -v mkarchiso >/dev/null || {
  echo "archiso is not installed; run: sudo pacman -S --needed archiso squashfs-tools rsync" >&2
  exit 1
}
[[ -f $RELENG/profiledef.sh ]] || {
  echo "stock archiso releng profile not found at $RELENG" >&2
  exit 1
}

VERSION="$(cat "$REPO/version")"
ISO_VERSION=${VERSION:-$(date +%Y.%m.%d)}

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$WORK/profile"
cp -a "$RELENG/." "$WORK/profile/"
rsync -a "$REPO/iso/profile/" "$WORK/profile/"
for overlay in "${EXTRA_OVERLAY[@]}"; do
  rsync -a "$overlay/" "$WORK/profile/"
done

sed -i "s/^iso_version=.*/iso_version=\"$ISO_VERSION\"/" "$WORK/profile/profiledef.sh"

# Bundle the MagikOS source tree (committed HEAD only, no .git) into the
# airootfs so the live environment can run the installer immediately.
mkdir -p "$WORK/profile/airootfs/root/magikos"
git -C "$REPO" archive --format=tar HEAD | tar -x -C "$WORK/profile/airootfs/root/magikos"
chmod -R a+rX "$WORK/profile/airootfs/root/magikos"

# mkarchiso copies the airootfs with --no-preserve=mode and then applies only
# the entries in profiledef.sh's file_permissions, so every bundled repo
# executable would lose its +x bit. Restore them by appending generated
# file_permissions entries for each file git tracks as executable.
{
  printf '\nfile_permissions+=(\n'
  git -C "$REPO" ls-files -s -z | awk -v RS='\0' '
    /^100755 / {
      split($0, rec, "\t")
      printf "  [\"/root/magikos/%s\"]=\"0:0:755\"\n", rec[2]
    }'
  printf ')\n'
} >> "$WORK/profile/profiledef.sh"

# Test builds: put a root shell on the serial console so a headless QEMU run
# can read the smoke-check markers.
if [[ -n $BOOT_CONSOLE ]]; then
  sed -i "s/^APPEND /&console=$BOOT_CONSOLE /" "$WORK"/profile/syslinux/*.cfg
  sed -i "s/^options  /&console=$BOOT_CONSOLE /" \
    "$WORK"/profile/efiboot/loader/entries/01-archiso-linux.conf
fi

if [[ -e $WORK/profile/airootfs/opt/magikos-smoke.sh ]]; then
  chmod +x "$WORK/profile/airootfs/opt/magikos-smoke.sh"
fi

mkdir -p "$OUT_DIR"
echo "==> Building magikos-$ISO_VERSION live ISO (releng + iso/profile overlay)"
mkarchiso -v -w "$WORK/work" -o "$OUT_DIR" "$WORK/profile"
echo "==> Done: $OUT_DIR/magikos-$ISO_VERSION-x86_64.iso"