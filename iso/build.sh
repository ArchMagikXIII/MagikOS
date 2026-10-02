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
#   ./iso/build.sh [-o OUT_DIR] [--extra-overlay DIR] [--boot-console DEV] [--live-root-password PWD]
set -euo pipefail

REPO="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RELENG=${RELENG:-/usr/share/archiso/configs/releng}

OUT_DIR="$REPO/iso/release"
EXTRA_OVERLAY=()
BOOT_CONSOLE=
LIVE_ROOT_PASSWORD=

while (( $# > 0 )); do
  case $1 in
    -o|--out-dir) OUT_DIR=$2; shift 2 ;;
    --extra-overlay) EXTRA_OVERLAY+=("$2"); shift 2 ;;
    --boot-console) BOOT_CONSOLE=$2; shift 2 ;;
    --live-root-password) LIVE_ROOT_PASSWORD=$2; shift 2 ;;
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

# Bundle the official CachyOS keyring package onto the live root so the
# installer can establish CachyOS key trust without any keyserver traffic
# (the keyring is tiny, ~5 KB). The installer imports the keyring it ships and
# lsigns the signing key; without this, gpg/dirmngr keyserver lookups must work
# from inside the target, which fails in NAT'd environments like qemu slirp.
keyring_file="$(curl -fsSL --max-time 30 'https://mirror.cachyos.org/repo/x86_64/cachyos/' \
  | grep -oE 'cachyos-keyring-[^"<]*\.pkg\.tar\.zst' | head -1)"
if [[ -n $keyring_file ]]; then
  curl -fsSL --max-time 60 -o "$WORK/profile/airootfs/root/cachyos-keyring.pkg.tar.zst" \
    "https://mirror.cachyos.org/repo/x86_64/cachyos/$keyring_file"
  echo "==> Bundled CachyOS keyring: $keyring_file"
else
  echo "==> WARNING: could not fetch the CachyOS keyring; installs will need keyserver access" >&2
fi

sed -i "s/^iso_version=.*/iso_version=\"$ISO_VERSION\"/" "$WORK/profile/profiledef.sh"

# Bundle the MagikOS source tree (no .git) into the airootfs so the live
# environment can run the installer immediately. Plant the WORKING TREE, not
# just HEAD: builds should test what is checked out. `git stash create -u`
# snapshots staged+unstaged+untracked (respecting .gitignore) without touching
# the checkout; it yields nothing when the tree is clean, so fall back to HEAD.
tree="$(git -C "$REPO" stash create -u)"
mkdir -p "$WORK/profile/airootfs/root/magikos"
git -C "$REPO" archive --format=tar "${tree:-HEAD}" \
  | tar -x -C "$WORK/profile/airootfs/root/magikos"
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

# Stock Arch PAM rejects empty passwords (upstream system-auth has no nullok)
# while the default archiso root account has none set, so the live session is
# unloggable out of the box. When a password is supplied, stamp it into the root
# account via the chroot customize_airootfs.sh hook: mkarchiso copies the
# airootfs overlay BEFORE pacstrap, so writing /etc/shadow directly would be
# overwritten by the base installation. Also ship an /etc/securetty that admits
# root over the serial console (ttyS0), which the stock file omits.
if [[ -n $LIVE_ROOT_PASSWORD ]]; then
  command -v openssl >/dev/null || { echo "openssl is required for --live-root-password" >&2; exit 1; }
  hash="$(openssl passwd -6 "$LIVE_ROOT_PASSWORD")"
  cat > "$WORK/profile/airootfs/root/customize_airootfs.sh" <<EOF
#!/bin/bash
usermod -p '$hash' root
# Arch base's post_install sets root's shell to /usr/bin/zsh even though zsh is
# not installed and /etc/shells does not list it; pam_shells then rejects every
# login ("Login incorrect"). Pin root to the installed bash.
usermod -s /usr/bin/bash root
EOF
  chmod 700 "$WORK/profile/airootfs/root/customize_airootfs.sh"
fi
printf 'console\ntty1\ntty2\ntty3\ntty4\ntty5\ntty6\nvc/1\nvc/2\nvc/3\nvc/4\nvc/5\nvc/6\nttyS0\nhvc0\n' \
  > "$WORK/profile/airootfs/etc/securetty"

mkdir -p "$OUT_DIR"
echo "==> Building magikos-$ISO_VERSION live ISO (releng + iso/profile overlay)"
mkarchiso -v -w "$WORK/work" -o "$OUT_DIR" "$WORK/profile"
echo "==> Done: $OUT_DIR/magikos-$ISO_VERSION-x86_64.iso"