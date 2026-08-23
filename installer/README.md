# Magikos Installer

An in-repo, distro-agnostic installer for Magikos. One script handles both Arch-based live media (pacman) and Fedora-based live media (dnf), then hands off to the same target-side setup the packaged ISO uses — `magikos-apply-system` runs in the target chroot, so an install from either backend gets identical hardware setup, config leaves, login assets, and post-install steps.

## Usage

Boot any live Linux with network access (CachyOS for pacman, Fedora Workstation netinst for dnf), clone or copy this repository onto the machine, then:

```bash
sudo ./installer/magikos-install --disk /dev/vda --user alice
```

Full options:

| Flag | Purpose |
|------|---------|
| `--disk DEVICE` | Whole target disk; its contents are destroyed. Required. |
| `--user NAME` | Non-root user to create (member of `wheel`). Required. |
| `--hostname NAME` | Target hostname (default `magikos`). |
| `--timezone TZ` | IANA timezone (default: the live media's). |
| `--no-encrypt` | Skip LUKS2 encryption of the root partition. |
| `--backend BE` | `pacman`, `dnf`, or `auto` (default: detect on the live media). |
| `--yes` | Do not ask before wiping. |
| `--dry-run` | Print every action without touching anything. |

## What it builds

- GPT layout: 1 GiB ESP + root, optionally wrapped in LUKS2 (`cryptsetup luksFormat --type luks2`)
- Btrfs with `@` (root) and `@home` subvolumes, matching the Snapper/Limine snapshot machinery shipped under `etc/` and `default/snapper/root`
- The Magikos tree planted at `/usr/share/magikos`, shipped defaults seeded through `/etc/skel`
- UKI + Limine on Arch (`ENABLE_UKI=yes` via `etc/limine-entry-tool.d/`); systemd-boot on Fedora [beta]
- User creation, wheel sudoers, locale/timezone/fstab/crypttab, then `magikos apply system --install-user <user>` inside the target

Every action is logged to `$MAGIKOS_INSTALL_LOG_FILE` (default `/tmp/magikos-install.log`).

## Current limitations

- **Not yet exercised end-to-end.** The script is written to the contracts above but has not completed a real-disk install; do a `--dry-run` first and expect the first real run in a disposable VM.
- **Arch package set assumes a CachyOS-flavored live media** — `limine-entry-tool`, `pacstrap`, and AUR-adjacent names in `install/magikos-base.packages` resolve there. A stock Arch ISO will report failures for names that are not in the main repos.
- **Fedora path is beta**: `install/magikos-base.packages` uses Arch package names; the dnf transaction installs a curated core set plus whatever names happen to match (`--skip-broken` keeps one unmapped name from killing the install) and reports everything that did not land. A proper Arch↔Fedora name map is the next piece of work.
- Unattended installs (the `cidata` contract documented in manual/52) are not implemented here yet; flags cover the same fields interactively.

## Roadmap

1. First end-to-end install in a VM (Arch/CachyOS backend), then Fedora backend.
2. Package-name mapping table so both `.packages` files speak both dialects.
3. `cidata` unattended support reading `user_configuration.json` / `user_credentials.json`.
4. Free-space (dual boot) mode alongside full-disk wipe.
