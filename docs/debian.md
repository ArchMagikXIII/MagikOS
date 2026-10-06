# Running Magikos on Debian

Magikos targets Arch/CachyOS. This document describes the Debian port: what runs, what is mapped onto apt, and what does not work yet.

Debian support is **adoption only**. There is no Debian equivalent of the Arch ISO flow (`installer/magikos-install` pacstraps an Arch root, writes mkinitcpio hooks, and drives a Limine UKI), so on Debian Magikos is applied to a system you already installed yourself. Bootloader, partitioning, initramfs, and kernel packages are all left alone.

## Entry point

```bash
sudo ./installer/magikos-install-debian --user alice
```

Add `--dry-run` first; it prints every action, touches nothing, and does not need root. Full flag list is in `installer/magikos-install-debian` itself and in [`../installer/README.md`](../installer/README.md).

The installer is idempotent — re-run it after a `git pull`.

## The package backend seam

Everything that installs, removes, or queries a package goes through `bin/magikos-pkg-backend`, a sourced library that resolves one of two backends:

| Symbol | pacman | apt |
|--------|--------|-----|
| `backend_is_pacman` / `backend_is_apt` | predicate on `MAGIKOS_PKG_BACKEND` | same |
| `pkg_installed` | `pacman -Q` | one `dpkg-query` pass resolving names *and* `Provides` |
| `pkg_list_available` | `pacman -Slq` | `apt-cache pkgnames` |
| `pkg_list_installed` | `pacman -Qq` | `dpkg-query -W`, filtered to `installed` |
| `pkg_list_explicit` | `pacman -Qqe` | `apt-mark showmanual` |
| `pkg_info_new` | `pacman -Sii` | `apt-cache show` |
| `pkg_info_installed` | `pacman -Qi` | `dpkg-query -s` |
| `PKG_INSTALL_CMD` | `pacman -S --noconfirm --needed` | `apt-get install -y` |
| `PKG_REMOVE_CMD` | `pacman -Rns --noconfirm` | `apt-get purge -y` |
| `PKG_AUTOREMOVE_CMD` | *(empty)* | `apt-get autoremove -y` |
| `PKG_UPGRADE_CMD` | `pacman -Syu` | `apt-get upgrade -y` |
| `PKG_SYNC_CMD` | `pacman -Syyuu` | `apt-get update` |

Detection prefers pacman when both managers are present, so an Arch host that also carries apt is still treated as Arch. `MAGIKOS_PKG_BACKEND=pacman|apt` forces the choice; tests use that to assert both shapes on one machine.

Two semantic differences are worth knowing:

- **`PKG_AUTOREMOVE_CMD` is new.** `pacman -Rns` collects orphaned dependencies in the same transaction, so pacman leaves the array empty. apt has no such verb, so `magikos-pkg-drop` runs the purge and the autoremove as two transactions, and only runs the second when the first succeeded.
- **`pkg_installed` resolves `Provides` on both backends.** dpkg reports virtual names through a `Provides` field rather than as installable names, and callers (notably the menu guards in `shell/plugins/menu/MenuModel.js`) expect a virtual name to answer true when something installed provides it. The apt implementation strips the version constraint (`foo (= 1.2)`) and architecture qualifier (`bar [amd64]`) before comparing, mirroring the pacman-side awk parser.

## The Debian package list

`install/magikos-base-debian.packages` is the apt counterpart of `install/magikos-base.packages`; the Arch list stays canonical for the ISO. Roughly 169 names. Every name in it resolves in Debian 13 / Parrot 7.4.

Names that differ from the Arch spelling:

| Arch | Debian |
|------|--------|
| `bind` | `bind9` |
| `wpa_supplicant` | `wpasupplicant` |
| `alsa-firmware` | `alsa-firmware-loaders` |
| `alsa-plugins` | `libasound2-plugins` |
| `amd-ucode` | `amd64-microcode` |
| `awesome-terminal-fonts` | `fonts-font-awesome` |
| `mako` | `mako-notifier` |
| `libva-dbus2` | `libva2` |
| `nss-mdns` | `libnss-mdns` |
| `xorg-xwayland` | `xwayland` |
| `mkinitramfs` | `initramfs-tools` |
| `poppler-glib` | `poppler-utils` |
| `ttf-bitstream-vera` | `fonts-dejavu-core` |
| `ttf-liberation` | `fonts-liberation` |
| `ttf-jetbrains-mono-nerd` | `fonts-jetbrains-mono` |
| `gst-libav`, `gst-plugin-va` | `gstreamer1.0-plugins-good`, `gstreamer1.0-libav` |
| `libspa-0.2-jack` | `pipewire-jack` (the Arch name is frozen at libspa 1.4 and conflicts with the `libspa-0.2-modules` current pipewire ships) |
| `openssh` | `openssh-client` + `openssh-server` + `openssh-sftp-server` |

Four more are translated at the backend seam rather than in the list, because the hardware tier asks for them by their Arch names from `install/hardware/*.sh`:

| Arch name asked for | installed as |
|---------------------|--------------|
| `sof-firmware` | `firmware-sof-signed` |
| `intel-media-driver` | `intel-media-va-driver-non-free` |
| `libva-intel-driver` | `intel-media-va-driver` |
| `broadcom-wl` | `broadcom-sta-dkms` |

`pkg_resolve_name` in `bin/magikos-pkg-backend` does that mapping, and `pkg_installed` resolves through it too so the post-install check in `magikos-pkg-add` still verifies what the caller asked for. Names Debian does not carry at all (`asusctl`, `qmk-hid`, `macbook12-spi-driver-dkms`, `linux-ptl`, `intel-ipu7-camera`, `intel-lpmd`, `linux-firmware-marvell`, `dell-xps-touchpad-haptics`) are deliberately **not** mapped: mapping them to nothing would report success for work that never happened, so they stay unresolvable and the best-effort hardware tier names them as skipped.

Dropped for want of a Debian equivalent: every `cachyos-*` package, `yay`/`yay-debug`/`paru`, `pacman-contrib` and the tools it carried (`bluetui`, `pkgfile`, `paccache`, `checkupdates`, `expac`), `reflector`, `topgrade`, `os-prober`, `hwdetect`, `netctl` (systemctl owns it), `mkusb`, `swaync`, `nano-syntax-highlighting`, `base`, `base-devel`, `libvpl`, `vpl-gpu-rt`, `egl-wayland`, `libpulse`.

The installer treats the list as best-effort, and it has to work harder than that to be useful on a derivative distro. apt installs in one transaction or not at all, so a single unresolvable name — or one strict dependency tie, which apt reports as a *solver* failure rather than a missing package — would otherwise cost the whole set. The installer installs in chunks of 24 and, when a chunk fails, retries that chunk one package at a time.

Per-package is the only way to tell a genuinely broken package from one that merely collided with its neighbours. Two real cases from a Parrot 7.4 run:

- `libspa-0.2-jack` (the Arch name) is frozen at libspa 1.4 and conflicts with the `libspa-0.2-modules` that current pipewire ships. Replaced with `pipewire-jack`.
- `openssh-server` requires `openssh-client` at the *same* version. On a host whose client came from backports (10.3p1) while the server is only in stable (10.0p1), apt tries to solve it as a downgrade and refuses. Correctly contained to that one package — but worth knowing that installing it may require pulling `openssh-server` from backports too.

## /etc handling

The Arch installer's `--existing` mode rsyncs the whole `etc/` tree over the live `/etc`. That is safe onto a system this project installed and unsafe onto a stock Debian box, because dpkg owns those files and reports conflicts through conffile prompts. `etc/` contains `nsswitch.conf`, `security/faillock.conf`, `gnupg/dirmngr.conf`, and `plymouth/plymouthd.conf` — a wrong `hosts:` line breaks DNS, and Magikos's faillock config relaxes the distribution's PAM lockout.

The Debian installer therefore splits them:

- **Drop-ins** (`ETC_DROPIN_FILES`) are installed from an explicit allowlist. Every path lands in a directory whose purpose is additive merging — `*.conf.d`, `sysctl.d`, `modprobe.d`, `tmpfiles.d`, `sudoers.d`, `profile.d` — so a write cannot clobber a same-named file the distribution ships. `--no-etc-dropins` skips them.
- **Whole-file host configuration** (`HOST_OVERRIDE_FILES`) is never applied directly. `--host-overrides` writes each as `<name>.magikos-new` next to the original for an administrator to diff and merge.

Limine's UKI entry tooling (`etc/limine-entry-tool.d/`) and the mkinitcpio drop-ins are excluded outright: they configure an Arch boot stack that does not exist here.

## Tolerant setup leaves

`magikos-apply-system` sources `install/config/all.sh`, `install/login/all.sh`, and `install/post-install/all.sh`, each leaf run through `run_logged` under `errexit`. One failing leaf aborts the rest of the chain, so a leaf that references a package the Debian base set does not install would take the whole setup down with it.

The leaves that reference an optional package or unit now no-op with a message instead:

| Leaf | Guarded on |
|------|-----------|
| `post-install/pacman.sh` | `backend_is_pacman` (also the leaf that aborts the chain first on a non-Arch system) |
| `config/firewall.sh` | `ufw` |
| `config/enable-services.sh` | each unit, via a new `enable_unit` helper (`avahi`, `sddm`, `systemd-oomd`, …) |
| `config/increase-lockout-limit.sh` | `/etc/pam.d/system-auth` *and* `/etc/pam.d/common-auth`; `sddm-autologin` only when SDDM ships it |
| `config/snapper.sh` | `snapper`; `limine-snapper-sync` enabled separately since it has no Debian package |
| `login/themes.sh` | SDDM and plymouth independently |
| `login/autologin.sh` | SDDM |
| `post-install/localdb.sh` | `updatedb` |
| `user/mise.sh`, `user/mise-work.sh` | `mise` (see below) |

`magikos-provision-user` matters as much here as `magikos-apply-system`: it runs `install/user/all.sh` through the same `run_logged` errexit, so one failing per-user leaf costs every leaf after it — including `default-keyring.sh`.

### The hardware tier is best-effort by design

`magikos-apply-hardware` sets `MAGIKOS_INSTALL_BEST_EFFORT=1`, which makes `run_logged` record a failed leaf and return success instead of aborting. Each hardware leaf is independently gated on a `magikos-hw-*` probe and installs one vendor package, so a failure means "this machine does not need it", not "stop". Without it, one unresolvable firmware name silently skipped every tweak queued behind it — `install/hardware/all.sh` is ~38 leaves deep.

The skipped leaves are listed by name at the end of the run rather than passing unnoticed. The config, login and post-install phases keep the strict default, where a failure really does mean the rest should not proceed.

## Desktop preferences are best-effort

`magikos-provision-user` sets the default browser and mailto handler at the end. `xdg-settings` dispatches to a desktop-specific writer — `kwriteconfig` under KDE, `dconf` under GNOME — so on a session whose toolkit config tools are absent (`XDG_CURRENT_DESKTOP=KDE` on Parrot, with no `kwriteconfig` installed) the call fails, and under errexit that would skip the migration bookkeeping and the `finalize-user` marker, making every later run redo the whole leaf. Both calls are now warnings, and the mailto handler is only set when `HEY.desktop` actually exists — it arrives with mise's `hey-cli`, which Debian does not get.

## mise

`mise` is not packaged for Debian or Parrot; on Arch it arrives as `mise-bin` from the MagikOS repo via a migration. Everything that installs a per-user tool (`magikos-mise-install codex`, `claude`, `opencode`, `gh`, the `github:`/`npm:`/`aqua:` specs) goes through it, so those wrappers are simply not provisioned here. The two leaves guard on `mise` and skip with a message rather than aborting the chain; `mise-work.sh` still creates `~/Work` and its `.mise.toml`, which is useful without the toolchain.

## Session startup

`$MAGIKOS_PATH` has to resolve for the bar, the menus, and every `magikos-*` binding. Debian gets it from three places, installed by the installer:

- `/usr/lib/environment.d/*.conf`, read by `systemd-environment-d-generator`. This is the important one on Debian: uwsm is optional here and most people start `sway` directly, and this file is what makes the variable resolve for systemd user services and a plain `sway` from a TTY. The Arch installer's `--existing` mode omits this step; the Debian installer includes it.
- `/usr/share/uwsm/env.d/10-magikos`, only when uwsm is installed.
- `/etc/profile.d/magikos.sh`, which sources `default/bash/env-bootstrap` for login shells.

Commands reach `$PATH` through `/usr/local/bin` symlinks into the planted tree, which precedes `/usr/bin` on Debian's default `PATH`.

- **No openssh.** The Debian list omits `openssh-client`/`-server`/`-sftp-server` outright. Debian ties the server to an exact `openssh-client` version, so on a host whose client came from backports the transaction is unsatisfiable and apt attempts a downgrade it refuses — it cost two failures on every install for a service the session never uses. An adopter who wants a remote shell installs it themselves, or pulls `openssh-server` from backports so it matches their client. `install/config/ssh-command-path.sh` and `ssh-keepalive.sh` still run; they only affect outgoing `ssh` and the PAM `PATH` for non-shell logins, so they are harmless without a server.
- **Initramfs generators differ.** `magikos-refresh-plymouth` rebuilds the initramfs so the new Plymouth theme is actually in it, and now picks whichever generator is present — `limine-mkinitcpio`, `mkinitcpio`, `update-initramfs`, or `dracut`. It used to assume `mkinitcpio` unconditionally, which on Debian meant `sudo: mkinitcpio: command not found`. That was not cosmetic: `themes.sh` is the last leaf in the strict login phase, so the failure aborted `magikos-apply-system` before `post-install/` ran and the `magikos-dns` symlink and udev reload were silently skipped. Both halves of `themes.sh` are now failure-tolerant for the same reason.

## Known gaps

- **Quickshell.** Debian ships 0.3.0. The MagikOS `quickshell-git` build changes `quickshell kill` to block until the instance exits, which `magikos-restart-shell` relied on to avoid overlapping a dying shell with its replacement. The restart now drains explicitly by polling `quickshell list`, so it is correct on both, but 0.3.0 still lacks the fork's `QS_DISABLE_FILE_WATCHER` / `QS_NO_RELOAD_POPUP` handling and some log-filter additions.
- **`topgrade` is not packaged**, so `magikos-update` has nothing to drive. `oh-my-posh` is installed as a pinned upstream binary by the installer; topgrade is left as a reported gap rather than fetched from an unpinned URL.
- **`magikos-update-*` and the channel commands are pacman-only.** `magikos-refresh-pacman`, `magikos-update-keyring`, `magikos-channel-set`, `magikos-update-aur-pkgs`, and `magikos-update-pkg-prune` have no apt equivalent and were not ported. The libalpm pre-transaction guard (`default/libalpm/hooks/`) has no dpkg equivalent either; apt's `Pre-Invoke` hooks cannot abort a transaction the way alpm's `AbortOnFail` does.
- **The boot stack is untouched.** mkinitcpio, `limine-mkinitcpio`, `/etc/kernel/cmdline`, `/etc/limine-entry-tool.d/`, and the Arch kernel variants in `magikos-other.packages` are all unrepresented. Hardware-specific packages (NVIDIA, DKMS, Intel media, Apple/T2) have no Debian list yet; `install/magikos-other-debian.packages` is unwritten.
- **The graphical acceptance suite** runs in a disposable Arch VM and has not been run against a Debian session.