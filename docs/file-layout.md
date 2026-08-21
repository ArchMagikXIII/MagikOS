# File layout

How `magikos/` is organized and where everything ends up on an installed
system.

## Mental model

Two Arch packages are built from this one repo (PKGBUILDs live in the
separate `magikos-pkgs` repository, under `pkgbuilds/`):

- **`magikos`** — runtime binaries (`bin/`, including `bin/magikos-dev-*`),
  install/finalize scripts (`install/`), migrations, themes, and the
  Quickshell desktop (`shell/`). Depends on `magikos-settings`.
- **`magikos-settings`** — everything that has to be on the target *before*
  the magikos package installs (specifically before `useradd -m` and the
  limine bootloader install): all `/etc/skel/**`, `/etc/` drop-ins,
  package-owned system files under `/usr/share` and `/usr/lib`, fonts,
  plymouth theme, sddm theme, branding, plus the limine/snapper configs
  (mkinitcpio hooks, limine-entry-tool drop-ins, snapper template, the
  `default/limine/` and `default/snapper/` trees, and the boot/snapshot
  story end-to-end). Also ships the three debug binaries
  (`magikos-debug`, `magikos-debug-idle`, `magikos-upload-log`) needed by
  the live ISO env.

Two other packages live in `magikos-pkgs` but stand alone:
`magikos-keyring` (GPG keys for pacman) and `magikos-nvim` (the Neovim
setup; independently seeds `/etc/skel`).

Some trees ship in neither package and exist only in the repo: `manual/`
(user manual chapters), `agents/skills/` (contributor task guides), `docs/`,
`test/`, and `plans/`.

Three layers populate `$HOME`:

1. **Seed** — `magikos-settings` ships static defaults to `/etc/skel/`.
   Arch's `useradd -m` copies that tree into a new user's `$HOME` at user
   creation. This is the only mechanism that touches a brand-new user's home
   for these files.
2. **Finalize** — `magikos-provision-user` (routed as `magikos finalize
   user`) runs once per user and handles the things `/etc/skel` can't do
   because they need `$HOME` expansion, the live `$MAGIKOS_PATH`, or runtime
   detection of system state.
3. **Resync** — `magikos-reinstall-configs` is the explicit, destructive
   command for an existing user to clobber their configs back to shipped
   defaults.

`/etc/skel` only fires at user creation. Existing users picking up new
defaults must use the resync command.

Deferred-provisioning installs (`magikos-apply-system --defer-provisioning`)
create no user at all: the ISO leaves `/var/lib/magikos/provisioning/pending`
behind, which arms `magikos-provision-owner.service` (shipped from
`install/provisioning/`, alongside the factory-reset finish unit and
`setup-form.sh`). On first boot `bin/magikos-provision-owner` creates the
user on tty1 and runs the finalize step itself.

Current generated theme state lives under
`~/.local/state/magikos/current/`. Keep `~/.config/magikos/` for files a user
may intentionally version in a dotfile manager, such as user themes, hooks,
shell layout, plugins, and themed template overrides.

## Build-time map (repo → installed paths)

```
magikos/                            built into          installed at
─────────────────────────           ──────────────      ────────────────────────────────────

bin/magikos-*                  ──►  magikos             /usr/bin/magikos-*
                                                        (and symlinks in /usr/share/magikos/bin/)
bin/magikos-debug,
bin/magikos-debug-idle,
bin/magikos-upload-log         ──►  magikos-settings    /usr/bin/  (needed before magikos is installed)

default/libalpm/hooks/*.hook
                                ──►  magikos             /usr/share/libalpm/hooks/*.hook

install/**                     ──►  magikos             /usr/share/magikos/install/
migrations/**                  ──►  magikos             /usr/share/magikos/migrations/
themes/**                      ──►  magikos             /usr/share/magikos/themes/
shell/**                       ──►  magikos             /usr/share/magikos/shell/
version                        ──►  magikos             /usr/share/magikos/version
                                                        + /etc/skel/.local/state/magikos/migrations/*

config/**                      ──►  magikos-settings    /etc/skel/.config/**         (seeds new users)
                                                        /usr/share/magikos/config/** (resync source)
etc/fastfetch/config.jsonc     ──►  magikos-settings    /etc/fastfetch/config.jsonc

applications/*.desktop         ──►  magikos-settings    /etc/skel/.local/share/applications/
                                                        /usr/share/magikos/applications/
default/applications/battlenet.desktop
                                ──►  magikos-settings    /usr/share/magikos/default/applications/
                                                        (installer-only launcher template)
applications/icons/*           ──►  magikos-settings    /usr/share/icons/hicolor/{48,256,scalable}/apps/

etc/**                         ──►  magikos-settings    /etc/**           (drop-ins we own outright)
  ├─ mkinitcpio.conf.d/{magikos_hooks,thunderbolt_module}.conf
  ├─ limine-entry-tool.d/{magikos-defaults,magikos-uki}.conf
  ├─ NetworkManager/, sudoers.d/, sysctl.d/, tmpfiles.d/,
  │  profile.d/magikos.sh, …                            (a summary — `ls etc/` for the full ~17-entry tree)
  └─ security/faillock.conf, nsswitch.conf,
     cups/cups-browsed.conf, plymouth/plymouthd.conf    /usr/share/magikos/etc-overrides/
                                                          → /etc/* (post_install cp -f, see below)

default/limine/limine.conf     ──►  magikos-settings    /usr/share/magikos/default/limine/limine.conf
default/limine/default.conf    ──►  magikos-settings    /usr/share/magikos/default/limine/default.conf
                                                        (template; ISO substitutes @@CMDLINE@@ → /etc/default/limine)
default/snapper/root           ──►  magikos-settings    /etc/snapper/config-templates/magikos
                                                        (+ /usr/share/magikos/default/snapper/root)

default/**                     ──►  magikos-settings    /usr/share/magikos/default/
  ├─ bash/env-bootstrap                                 /usr/share/magikos/default/bash/env-bootstrap
  │                                                       (sourced by every shell/session entry point; see "Env bootstrap")
  ├─ bashrc                                             /usr/share/magikos/etc-overrides/dot.bashrc
  │                                                       → /etc/skel/.bashrc (post_install cp -f)
  ├─ hypr/toggles/*.lua (flags,
  │    single-window-aspect-ratio, window-no-gaps)      /etc/skel/.local/state/magikos/toggles/hypr/
  ├─ nautilus-python/extensions/*.py                    /etc/skel/.local/share/nautilus-python/extensions/
  ├─ tensaku/state.toml                                 /etc/skel/.local/state/tensaku/state.toml
  ├─ uwsm/env.d/10-magikos                              /usr/share/uwsm/env.d/
  ├─ environment.d/*.conf                               /usr/lib/environment.d/
  ├─ fontconfig/conf.avail/50-magikos.conf              /usr/share/fontconfig/conf.avail/
  │                                                       + symlink /etc/fonts/conf.d/50-magikos.conf
  ├─ xdg-terminal-exec/*.list                           /usr/share/xdg-terminal-exec/
  ├─ applications/mimeapps.list                         /usr/share/applications/mimeapps.list
  ├─ systemd/user/*.service                             /usr/lib/systemd/user/
  ├─ systemd/user/app.slice.d/10-oomd.conf              /usr/lib/systemd/user/app.slice.d/
  ├─ systemd/system-sleep/{force-igpu,
  │    keyboard-backlight,unmount-fuse}                 /usr/lib/systemd/system-sleep/
  ├─ systemd/zram-generator.conf.d/90-magikos.conf      /usr/lib/systemd/zram-generator.conf.d/
  ├─ fonts/magikos/magikos.ttf                          /usr/share/fonts/magikos/
  ├─ sddm/magikos/                                      /usr/share/sddm/themes/magikos/
  ├─ sddm/hyprland.lua                                  /usr/share/sddm/hyprland.lua
  ├─ wayland-sessions/magikos.desktop                   /usr/local/share/wayland-sessions/
  └─ plymouth/                                          /usr/share/plymouth/themes/magikos/

logo.{txt,svg}, icon.{txt,png}  ──► magikos-settings    /usr/share/magikos/  (resync source)
                                                        /usr/share/pixmaps/magikos.png
                                                        /usr/share/icons/hicolor/256x256/apps/magikos.png
                                                        /etc/skel/.config/magikos/branding/{about,screensaver}.txt
```

### Why `etc-overrides/` exists

Some files under `/etc/` (`.bashrc` in `/etc/skel`, `nsswitch.conf`,
`security/faillock.conf`, `cups/cups-browsed.conf`, `plymouth/plymouthd.conf`)
are owned by upstream Arch packages, so we can't install over them via pacman
without a file conflict. Instead their sources (under `etc/` in the repo;
`.bashrc` from `default/bashrc`) ship at
`/usr/share/magikos/etc-overrides/` and the `magikos-settings` `post_install`
/ `post_upgrade` scriptlet `cp -f`'s them into place.

Tradeoff: user edits to those files get clobbered on every `magikos-settings`
upgrade. This is documented in the PKGBUILD.

## Env bootstrap (`default/bash/env-bootstrap`)

Single source of truth for `MAGIKOS_PATH` and dev-link-aware `PATH`. It:

- Sources `/etc/magikos.conf` (written by `magikos-dev-link`, reset to the
  package path by `magikos-dev-unlink`) if present; otherwise forces
  `MAGIKOS_PATH=/usr/share/magikos` so a stale inherited value can't survive
  an `magikos-dev-unlink`.
- Prepends `$MAGIKOS_PATH/bin` to `PATH` **only when** `MAGIKOS_PATH` is
  not `/usr/share/magikos`. On a production install the binaries are
  already on `PATH` as `/usr/bin/magikos-*` via the `magikos` package.
- Appends `~/.local/share/mise/shims` and `~/.local/bin` so login shells and
  the uwsm session find mise-managed tools — kept in sync with the PAM `PATH`
  line written by `install/config/ssh-command-path.sh`, which covers SSH
  commands that run no shell setup at all.

Sourced by every entry point that needs the env set:

```
/etc/profile.d/magikos.sh                      (system login shells)
/etc/skel/.bashrc                              (interactive shells)
/usr/share/uwsm/env.d/10-magikos               (Hyprland session via uwsm)
/usr/share/magikos/default/bash/envs           (SSH / non-login bash)
```

Idempotent — safe to source more than once in the same shell.

`PATH` covers everything the user runs, but not `sudo`, which resolves command
names against `secure_path` from `/etc/sudoers`. So `magikos-dev-link` also
writes `/etc/sudoers.d/magikos-dev-path`:

```
Defaults secure_path="<checkout>/bin:/usr/local/sbin:/usr/local/bin:/usr/bin"
```

Without it, `sudo magikos-*` fails for a command the package has not shipped
yet and silently runs the packaged copy of one it has. The drop-in is validated
with `visudo -c` before install and removed by `magikos-dev-unlink`; unlike
`/etc/magikos.conf`, it takes effect without a reboot.

## Runtime finalization (`magikos-provision-user`)

Runs once per user. It does **not** copy `~/.config/**`, `~/.bashrc`,
`flags.lua`, or the nautilus extensions — `/etc/skel` already seeded those.
It only does the things `/etc/skel` can't:

- Skill symlinks `~/.{agents,claude,codex,pi/agent}/skills/<name>` →
  `$MAGIKOS_PATH/default/agents/skills/<name>`, looping over every skill
  directory there (currently `magikos` and `diagnose-crash`) so new skills
  need no edit. Symlinks (not copies) so `magikos dev link` against a dev
  checkout repoints them correctly.
- `xdg-user-dirs-update` (Templates/Public/Desktop folded back into `$HOME`)
  and `~/.config/gtk-3.0/bookmarks` (needs `$HOME` expansion).
- Hyprland's package-owned default input reads `XKBLAYOUT` / `XKBVARIANT`
  from `/etc/vconsole.conf`; no per-user Hyprland config rewrite is needed.
- `xdg-settings set default-web-browser chromium.desktop` and
  `xdg-mime default HEY.desktop x-scheme-handler/mailto` (XDG-aware paths).
- `magikos-refresh-applications` (composes generated `.desktop` launchers).
- Sources `install/user/all.sh` — theme, chromium, git, xcompose, mise,
  keyring, per-user hardware quirks (asus mic/mixer, framework f13 audio, …).
- On `--first-install`, marks every shipped user migration as already applied
  for the freshly-created user.

Idempotency marker: `~/.local/state/magikos/done/finalize-user`, managed
by `magikos-done`.

The ISO calls it as `magikos-provision-user --force --first-install` in the
target chroot as the install user, after `magikos-apply-system` has finished
the root-side work. `magikos-provision-owner` makes the same call (with
`MAGIKOS_SETUP_CONTEXT=provision-owner`) when it creates the user during
deferred first-boot provisioning.

## Migrations (`magikos-migrate`)

See [`migrations.md`](../agents/skills/migrations.md) for the full migration model, authoring
guidelines, and troubleshooting notes.

Magikos migrations live in `migrations/*.sh` and run per-user through
`magikos-migrate`. Completion state lives in
`~/.local/state/magikos/migrations/`, so every user gets a chance to run every
migration. Migrations run as the user; privileged work should invoke the
appropriate helper or privilege prompt. Migrations must be idempotent;
machine-wide repairs should no-op when another user already applied them.

Each graphical user has `magikos-migrate-notify.service`, started once per login
through `WantedBy=graphical-session.target` and ordered after that target so
notification actions can safely launch through UWSM. The `magikos-pkgs`
PKGBUILD has shipped `magikos-update-user-notify.service` as a symlink onto
it, so users enabled under the old unit name keep working before they reach
migration `1785095882`.
It runs `magikos-migrate-notify` as
that user, which checks `magikos-migrate --pending`. If this user has missing
migration state, it shows a notification that opens a terminal for
`magikos-migrate`. The notifier never runs migrations in the background.

Login is the only trigger. Nothing watches the packaged migration directory: a
watcher cannot tell a bypassed `pacman -Syu` from the package transaction inside
a normal `magikos update`, so it notified about migrations that `magikos-migrate`
was already applying in the visible update terminal.

`magikos-migrate` waits for any active pacman transaction to finish, then runs
pending migrations. It does not need `--force`; migrations happen when state
files are missing. `magikos update` runs `magikos-migrate` after the package
transaction in the already-visible update terminal, then runs
`magikos-hook post-update`.

## First-run (`magikos-provision-first-run`)

Runs once on first interactive login, after the user manager is live. It
first runs `magikos-provision-user || true` so finalize catches up if it
never ran, then handles the steps that need a running graphical session
and/or a working user systemd instance:

- `magikos-hook-install post-update` for the three shipped hooks
  (`install-voxtype.hook`, `setup-fingerprint.hook`, `setup-agent.hook`).
- `install/user/first-run/enable-user-units.sh` — daemon-reload, then
  `systemctl --user enable --now` the shipped user units (`bt-agent`,
  `magikos-sleep-lock`, `magikos-recover-internal-monitor`,
  `magikos-migrate-notify.service`, `magikos-fcitx5.service`,
  `magikos-crash-watch.service`) so they run in the first session too.
  Done here, not at finalize, because
  the user manager isn't reachable from the ISO chroot; `ConditionPath*`
  in the unit files keeps services inert when they don't apply.
- `install/user/first-run/gnome-theme.sh`,
  `install/user/first-run/gtk-primary-paste.sh` — GNOME/GTK settings that
  need the dconf daemon.
- `install/user/first-run/audio-tuning.sh` — apply speaker tuning.
- `install/user/first-run/welcome.sh` — keybindings toast that greets the
  first login and opens the cheatsheet when clicked. The caller runs
  `magikos-notification-wait` once before this and the Wi-Fi step, so both
  toasts land on a live notification server.
- `install/user/first-run/wifi.sh` — Wi-Fi/update toasts (waits detached on
  `nm-online` so the update prompt only lands once there is a connection).

The entire sequence has one idempotency marker:
`~/.local/state/magikos/done/first-run-user`, managed by `magikos-done`.
Completed users exit before any first-run step. On failure the marker is not
written and the sequence retries next login.

Completion markers live under `~/.local/state/magikos/done/`. Use
`magikos-done check <name>` to check one and `magikos-done mark <name>` to record it.
Use `magikos-done ensure <name>` as a conditional when the guarded work should
run only once; it records completion before returning success.
The Quattro upgrade completes graphical first-run for upgraded users and moves
the legacy finalization marker from `~/.local/state/magikos/` into `done/`.

## Root-side install orchestration

`magikos-apply-system` (root, in chroot) runs target-side setup at ISO
finalization. It sources:

- `install/config/all.sh` — theme links, lockout limits, lockscreen PAM,
  powerprofilesctl shebang fix, SSH command path and keepalive, docker setup,
  Snapper retention, locate index tuning, service enablement, firewall.
- `install/hardware/all.sh` via `magikos-apply-hardware` — vendor- and
  device-specific kernel modules, udev rules, microcode, wireless regdom,
  ASUS / Framework / Intel / Apple / Lenovo quirks.
- `install/login/all.sh` — SDDM theme/session config.
- `install/post-install/all.sh` — final pacman/udev/localdb passes.

Logging goes to `/var/log/magikos-install.log` via
`install/helpers/logging.sh`.

The package lists the ISO pacstraps live at `install/magikos-base.packages`
and `install/magikos-other.packages`; the ISO builder also reads them when
constructing its offline mirror.

## Explicit resync (`magikos-reinstall-configs`)

When an existing user wants to reset to shipped defaults:

```
~/  ←  cp -af /etc/skel/.
```

Replaying `/etc/skel` over `$HOME` is exactly what `useradd -m` does for a
brand-new user, so this one copy resyncs `.bashrc`, `.config/**`,
`.local/share/applications/`, the nautilus-python extensions, hypr toggles,
branding files, and the shipped migration markers in a single pass.

Then it runs `magikos-refresh-limine`, `magikos-refresh-plymouth`, and the
nvim refresh. Destructive: existing user files copied from `/etc/skel` are
clobbered without backup. Fastfetch is package-owned at
`/etc/fastfetch/config.jsonc`; delete `~/.config/fastfetch/config.jsonc` to
return to the packaged default.

## Quick reference: where does X live?

| Goal | Touch |
| --- | --- |
| Default file at `~/.config/foo/` | `config/foo/` |
| `/etc/` drop-in we own outright | `etc/` |
| `/etc/` file owned by an upstream package | `etc/` (see `etc/security/faillock.conf`), then add to `etc-overrides` in `magikos-settings` PKGBUILD + scriptlet |
| Package-owned system file (e.g. systemd user service in `/usr/lib`) | `default/`, then add the `install -Dm644` line in `magikos-settings` PKGBUILD |
| Per-user file that's static but lives outside `~/.config` | `default/`, then add `install -Dm644 ... $pkgdir/etc/skel/...` in `magikos-settings` PKGBUILD |
| Runtime tweak that needs `$HOME` or live system state | extend `magikos-provision-user`, or add a per-user leaf under `install/user/` and wire into `install/user/all.sh` |
| One-time root-side setup step | `install/config/*.sh` or `install/hardware/*.sh`, wire into `install/config/all.sh` or `install/hardware/all.sh` |
| One-time fix for existing installs | `migrations/<unix-timestamp>.sh` |
| Package-owned path something else may already write | Prefer a path nothing else writes, such as a vendor drop-in under `/usr/lib`. Otherwise the `--overwrite` entry in `bin/magikos-update-system-pkgs` has to ship a release before the file |
| User-facing `magikos-*` command | `bin/magikos-<group>-<verb>` — see `GROUP_DESCRIPTIONS` in `bin/magikos` |
| New stock theme | `themes/<name>/` (+ matching templates under `default/themed/` if they need theme colors) |
| User-installed theme | `~/.config/magikos/themes/<name>/` |
| Generated current theme/background state | `~/.local/state/magikos/current/` |
