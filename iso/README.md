# MagikOS live ISO

A minimal, bootable live ISO for MagikOS. Untested scaffold — this is the first
concrete form of an idea that was previously only roughed out. The ISO is the
stock archiso `releng` profile plus the MagikOS overlay in `iso/profile/`:

- the live environment carries a minimal package set — just enough to run
  `installer/magikos-install` (pacstrap, sgdisk, mkfs.\*, cryptsetup, gum,
  git, base-devel for AUR builds on `--existing`)
- the repo tree (committed HEAD, no `.git`) is bundled at `/root/magikos`
- boot reaches a tty1 root login; the motd and `.bashrc` point at the installer

Stock Arch PAM rejects empty passwords, so a live root password must be stamped
at build time — pass `--live-root-password <pwd>` or the login prompt will refuse
root. The smoke-test build pins `magikos`.

The archiso bootloader configs are releng's, so the boot menu still lists a
couple of entries for packages the minimal set omits (memtest, speech). They
are harmless; pruning them is future polish.

## Build

```bash
sudo pacman -S --needed archiso squashfs-tools rsync
sudo ./iso/build.sh --live-root-password magikos
```

Produces `iso/release/magikos-<version>-x86_64.iso`. Log in on the live console
or serial line as `root` with the password you passed to `--live-root-password`.

If QEMU's GTK window shows a black screen (seen on Wayland/Sway hosts — the
syslinux splash renders, then the text console goes blank while the guest is in
fact booting), run QEMU headless and drive it from the terminal instead:
`-display curses` (BIOS menu is graphical and won't paint — wait ~15s for the
default entry to auto-boot) or, for a serial-console build,
`-display none -serial stdio`.

## Smoke-test in a VM

```bash
sudo ./iso/test.sh
```

Builds a test variant (boot-time marker script plus a serial console), boots it
in QEMU/KVM, and asserts the markers under `iso/test-runs/<timestamp>/serial.log`
— that the image boots, `/root/magikos` is present, and the installer is
syntactically valid.

## What has NOT been validated yet

- an actual end-to-end install from the ISO: wipe a VM disk, install MagikOS on
  it, and boot the result
- the UEFI boot path (test.sh boots in BIOS mode; OVMF would be needed to check
  the systemd-boot path)
- booting on real hardware

## Install from it

Boot the ISO under QEMU or hardware, then on the live tty:

```bash
bash /root/magikos/installer/magikos-install --disk /dev/sda --user you
```

(Full options: `bash /root/magikos/installer/magikos-install --help`.)