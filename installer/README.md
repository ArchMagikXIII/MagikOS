# Magikos Installer

An in-repo installer for Magikos. Full-disk installs build an Arch/CachyOS target. Existing-system adoption also has an experimental Artix OpenRC path that deliberately uses a smaller package set and separate session setup instead of the Arch system finalizer.

Debian and derivatives have their own adoption-only installer, [`magikos-install-debian`](magikos-install-debian); see [`../docs/debian.md`](../docs/debian.md) for the port's scope and gaps.

## Usage

Two modes: full-disk install from live media, and adoption of an already-running system.

### Full-disk install

Boot a CachyOS live ISO (or any Arch live media with network access), clone or copy this repository onto the machine, then:

```bash
sudo ./installer/magikos-install --disk /dev/vda --user alice
```

### Existing-system adoption

On a running Arch/CachyOS system (or, experimentally, Artix with OpenRC), clone the repo anywhere and run:

```bash
sudo ./installer/magikos-install --existing
```

On Arch/CachyOS, adoption plants `/usr/share/magikos`, assembles `/etc/skel`, attempts the package set, creates `--user` if missing, runs `magikos-apply-system` and finalizes the user. On Artix OpenRC it requires an existing user, installs a smaller repo-only package set, plants the tree, runs the OpenRC-only setup and backs up the user's Sway config before copying Magikos defaults; it never runs the Arch system finalizer. Missing packages or failed setup make adoption exit nonzero rather than claim success. Neither mode repartitions the disk. Artix keeps its existing bootloader and should **not** run the Arch-only direct-boot setup.

Full options:

| Flag | Purpose |
|------|---------|
| `--disk DEVICE` | Whole target disk; its contents are destroyed. Required for full-disk mode. |
| `--user NAME` | Non-root user to create. Required for full-disk mode; optional with `--existing`. |
| `--existing` | Adopt the running system instead of wiping a disk. |
| `--hostname NAME` | Target hostname (default `magikos`; ignored with `--existing`). |
| `--timezone TZ` | IANA timezone (default: the live media's; ignored with `--existing`). |
| `--no-encrypt` | Skip LUKS2 encryption of the root partition. |
| `--cachyos-repos` | Add the CachyOS repositories before the package install. On any base without them (e.g. stock Arch), they are auto-added and — when the terminal allows it — the installer asks first. `--no-cachyos-repos` forces them off. |
| `--autologin` | Log the user in automatically at the MagikOS login screen (default: the MagikOS password prompt at every boot). |
| `--yes` | Do not ask before wiping. |
| `--dry-run` | Print every action without touching anything. |

## What it builds

- GPT layout: 1 GiB ESP + root, optionally wrapped in LUKS2 (`cryptsetup luksFormat --type luks2`)
- Btrfs with `@` (root) and `@home` subvolumes, matching the Snapper/Limine snapshot machinery shipped under `etc/` and `default/snapper/root`
- The Magikos tree planted at `/usr/share/magikos`, shipped defaults seeded through `/etc/skel`
- UKI + Limine (`ENABLE_UKI=yes` via `etc/limine-entry-tool.d/`)
- User creation, wheel sudoers, locale/timezone/fstab/crypttab, then `magikos apply system --install-user <user>` inside the target

Every action is logged to `$MAGIKOS_INSTALL_LOG_FILE` (default `/tmp/magikos-install.log`).

## Current limitations

- **Not yet exercised end-to-end.** The script is written to the contracts above but has not completed a real-disk install; do a `--dry-run` first and expect the first real run in a disposable VM.
- **Artix OpenRC adoption is experimental, not a full-disk Artix installer.** `--existing` auto-detects Artix/OpenRC and uses `magikos-base-artix-openrc.packages`; it requires an existing user and refuses a configured CachyOS repo or missing Artix packages before changing files. It installs only repo packages in an interactive pacman transaction without `--overwrite`, `--noconfirm`, auto conflict removal or AUR; refuse any prompt to remove essential Artix packages. Package transaction failure stops before the Magikos tree is planted. It keeps the current kernel, bootloader, pacman config, network, firewall, init and display manager. It does not run the Arch system/user finalizers. Select **Magikos (OpenRC)** at your existing login screen. The separate Sway session starts Quickshell and Artix's packaged PipeWire user services, and uses direct-app/Foot fallbacks instead of a systemd user manager. Do not treat this as production ready until an Artix VM has exercised the actual install, audio, suspend/lid lock, and next boot. The post-install pacman step and `magikos refresh pacman` preserve/refuse to replace Artix's repository configuration. An older installer may have appended a `[cachyos]` section: back up `/etc/pacman.conf` and remove only that section and its `Include` line, leaving `[system]`, `[world]`, `[galaxy]` and `[lib32]` intact.
- **Arch package set assumes a CachyOS-flavored live media** — `limine-entry-tool`, `pacstrap`, and AUR-adjacent names in `install/magikos-base.packages` resolve there. When the base lacks the CachyOS repos, the installer adds them (see `--cachyos-repos`) so the cachyos-* set and `linux-cachyos` install as binaries; without them those names are retried through `yay`, which the installer builds from the AUR when it is missing. A stock Arch ISO still needs network access for the keyring step.
- **`--existing` leaves the bootloader alone** by design; a system booting GRUB or plain systemd-boot gets all userspace setup but keeps its current boot path until you run `magikos setup direct-boot`.
- Unattended installs (the `cidata` contract documented in manual/52) are not implemented here yet; flags cover the same fields interactively.

### Artix/OpenRC VM validation (required before relying on it)

Keep a VM snapshot and retain your current login session as a fallback. On the guest, check `pacman-conf --repo-list` (no `[cachyos]`), then run `sudo ./installer/magikos-install --existing --user "$USER" --dry-run` to review the plan. Only then run the non-dry-run command and verify it exits zero. Confirm `rc-update show boot` contains elogind, and `rc-update show default` contains dbus. Choose **Magikos (OpenRC)** from your existing login manager; verify Quickshell starts, `wpctl status` works (or inspect `~/.local/state/magikos/openrc-services.log`), applications and terminal launch, and `magikos-system-suspend` leaves a secure lock after resume. Test lid-close separately. Finally reboot and confirm the original login session, bootloader and Artix repositories still work. If any step fails, do **not** treat the install as complete or enable autologin; keep the install log and session logs for diagnosis. The host cannot access the current VM's guest agent, so these guest checks have not been run here.

## Roadmap

1. First end-to-end install in a VM.
2. `cidata` unattended support reading `user_configuration.json` / `user_credentials.json`.
3. Free-space (dual boot) mode alongside full-disk wipe.
