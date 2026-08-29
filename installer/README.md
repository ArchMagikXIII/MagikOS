# Magikos Installer

An in-repo installer for Magikos, built for Arch/CachyOS (pacman). One script handles a full-disk install from live media and adoption of an already-running system, then hands off to the same target-side setup the packaged ISO uses — `magikos-apply-system` runs in the target chroot, so both paths get identical hardware setup, config leaves, login assets, and post-install steps.

## Usage

Two modes: full-disk install from live media, and adoption of an already-running system.

### Full-disk install

Boot a CachyOS live ISO (or any Arch live media with network access), clone or copy this repository onto the machine, then:

```bash
sudo ./installer/magikos-install --disk /dev/vda --user alice
```

### Existing-system adoption

On a running Arch/CachyOS system, clone the repo anywhere and run:

```bash
sudo ./installer/magikos-install --existing
```

This plants the tree at `/usr/share/magikos`, assembles `/etc/skel` the way the `magikos-settings` package would (`config/**` → `.config/**`, `default/bashrc` → `.bashrc`, desktop entries and hicolor icons), installs the package set best-effort, creates `--user` if missing (defaults to the invoking user), runs `magikos-apply-system` directly on the host, then replays shipped defaults into the user's `$HOME` and runs per-user finalization as that user. It does **not** partition, touch fstab/hostname/locale, or modify the bootloader — adopt the UKI/Limine layout afterwards with `magikos setup direct-boot` when ready. Shipped defaults overwrite matching files in the user's home immediately (the confirmation prompt covers this).

Full options:

| Flag | Purpose |
|------|---------|
| `--disk DEVICE` | Whole target disk; its contents are destroyed. Required for full-disk mode. |
| `--user NAME` | Non-root user to create. Required for full-disk mode; optional with `--existing`. |
| `--existing` | Adopt the running system instead of wiping a disk. |
| `--hostname NAME` | Target hostname (default `magikos`; ignored with `--existing`). |
| `--timezone TZ` | IANA timezone (default: the live media's; ignored with `--existing`). |
| `--no-encrypt` | Skip LUKS2 encryption of the root partition. |
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
- **Arch package set assumes a CachyOS-flavored live media** — `limine-entry-tool`, `pacstrap`, and AUR-adjacent names in `install/magikos-base.packages` resolve there. Names absent from the repos (AUR-only packages) are retried through `yay`, which the installer builds from the AUR when it is missing; a stock Arch ISO still needs network access for that step.
- **`--existing` leaves the bootloader alone** by design; a system booting GRUB or plain systemd-boot gets all userspace setup but keeps its current boot path until you run `magikos setup direct-boot`.
- Unattended installs (the `cidata` contract documented in manual/52) are not implemented here yet; flags cover the same fields interactively.

## Roadmap

1. First end-to-end install in a VM.
2. `cidata` unattended support reading `user_configuration.json` / `user_credentials.json`.
3. Free-space (dual boot) mode alongside full-disk wipe.
