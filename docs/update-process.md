# Magikos update process

This document describes the intended update behavior now that Magikos is
package-backed. It covers the blessed update path plus what happens when a user attempts to
bypass it:

1. `magikos update` — the blessed interactive Magikos update flow.
2. `sudo pacman -Syu` — guarded by Magikos and aborted with instructions unless
   the user explicitly bypasses the guard.

The design goal is:

- `magikos update` owns the visible update pipeline: package transaction,
  migrations, post-update hooks, update-state refresh, and restart checks.
- Migrations run per-user after pacman finishes, because they may need `$HOME`,
  DBus/session state, a graphical session, sudo, or user interaction.
- Users who bypass `magikos update` are nudged back by the pacman guard; if they
  explicitly bypass it, their session is notified when migrations are pending.

## State and coordination files

| Path | Owner | Purpose |
| --- | --- | --- |
| `${XDG_RUNTIME_DIR:-/tmp}/magikos-update.lock` | user | Prevent overlapping update runs. Owned by `magikos-update-lock`; compatibility wrappers inherit/respect it. |
| `/tmp/magikos-update.log` | user | Transcript of `magikos update`, used by `magikos-update-analyze-logs`. |
| `~/.local/state/magikos/current/` | user | Generated active theme, selected theme name, and current background symlink. |
| `~/.local/state/magikos/migrations/` | user | Per-user migration markers. |
| `~/.local/state/magikos/reboot-required` | user | Optional reboot marker checked by `magikos-update-restart`. |
| `~/.local/state/magikos/restart-*-required` | user | Optional service/app restart markers checked by `magikos-update-restart`. The shell needs no marker: it is restarted unconditionally after every update. |

## Migration layout

See [`migrations.md`](../agents/skills/migrations.md) for the full migration model, authoring
guidelines, and troubleshooting notes.

Migrations live in:

```text
migrations/*.sh
```

They run as the current user through:

```bash
magikos-migrate
```

Completion state is per-user:

```text
~/.local/state/magikos/migrations/<migration filename>
```

Every user gets a chance to run every migration. Migrations run as the user;
privileged work should invoke the appropriate helper or privilege prompt.
Migrations must be idempotent; if one user already applied a machine-wide repair,
the migration should no-op for other users.

For watchers and diagnostics, `magikos-migrate --pending` prints pending
migration names and exits `0` when any are pending. When no migrations are
pending, it prints nothing and exits non-zero.

## Raw pacman guard

The `magikos` package installs an ALPM pre-transaction hook alongside its guard
binary:

```text
/usr/share/libalpm/hooks/00-magikos-update-guard.hook
/usr/bin/magikos-update-pacman-guard
```

It triggers on package upgrades and runs:

```bash
magikos-update-pacman-guard
```

The guard detects direct pacman system-upgrade commands like `pacman -Syu` or
`pacman --sync --refresh --sysupgrade`. If the upgrade was not launched by an
Magikos update command, the hook exits non-zero with `AbortOnFail`, which stops
the transaction before packages are changed.

`magikos-update-system-pkgs`, `magikos-refresh-pacman`, `magikos-reinstall-pkgs`,
`magikos-channel-set`, and the v4 upgrader run pacman through:

```bash
env MAGIKOS_UPDATE_PACMAN=1 pacman ...
```

so the guard allows Magikos-owned update flows. A user can intentionally bypass
the guard with:

```bash
sudo env MAGIKOS_ALLOW_DIRECT_PACMAN=1 pacman -Syu
```

The guard does not start `magikos update` itself because pacman is already in a
transaction setup path; it only aborts with instructions.

The `magikos` package also installs ALPM hooks for `magikos-settings` /
`magikos-settings-dev` installs and upgrades. The pre-transaction hook runs
`magikos-hyprland-reload-guard pause` to disable live Hyprland config reloads
while `/usr/share/magikos/default/hypr/**` is replaced. The post-transaction
hook runs `magikos-hyprland-reload-guard resume`, forces one `hyprctl reload`,
and restores the session's previous `misc.disable_autoreload` and
`debug.suppress_errors` values.

## Path 1: `magikos update`

High-level flow:

```text
magikos-update
  ├─ ensure transcript logging through script(1) → /tmp/magikos-update.log
  ├─ magikos-update-lock
  │    └─ acquire the update lock and run magikos-update inside it
  ├─ magikos-update-requires-free-space
  │    └─ abort below the configured free-space threshold on /
  ├─ confirm unless -y
  ├─ magikos-update-pkg-prune
  │    └─ trim the pacman cache to two versions per package, deliberately
  │       before the snapshot since the cache lives on the snapshotted subvolume
  ├─ create snapper snapshot (skipped silently without snapper; snapper
  │  installed but unconfigured fails the snapshot loudly, pointing at
  │  install/config/snapper.sh, and the update continues without one)
  ├─ magikos-update-stay-awake start
  ├─ run package updates, migrations, hooks, and log analysis
  ├─ magikos-update-status
  │    └─ refresh or clear the shell update indicator
  ├─ magikos-update-stay-awake stop
  │    └─ release the sleep inhibitor and restore shell idle state, if changed
  └─ magikos-update-restart
```

Important behavior:

- In dev-link mode, `magikos update` fast-forwards the active checkout from its
  configured upstream before changing system packages or running migrations.
- `-y` exports `MAGIKOS_UPDATE_UNATTENDED=1` — a promise not to ask anything.
  Steps that would prompt (orphan removal, conflict handoff) report and skip
  instead of blocking.
- The free-space requirement uses a 10 GiB threshold and stops the update before
  confirmation when it is not met. If free space cannot be determined, the
  check is silently skipped. Set `MAGIKOS_UPDATE_FORCE=1` to bypass the check.
- `magikos update` checks/runs migrations in the same visible terminal via
  `magikos-migrate` after pacman finishes.
- A failure should leave enough output in `/tmp/magikos-update.log` and the
  terminal transcript to debug.

## Path 2: direct `sudo pacman -Syu` attempt

High-level flow:

```text
sudo pacman -Syu
  ├─ pre-transaction guard aborts and tells the user to run magikos update
  └─ if explicitly bypassed, upgrades magikos and related packages
  └─ at that user's next login
       ├─ graphical-session.target starts
       ├─ magikos-migrate-notify.service starts after it
       ├─ magikos-migrate-notify checks magikos-migrate --pending
       ├─ if this user has missing migration state, show notification
       └─ click opens terminal: magikos-migrate
```

Login is deliberately the only trigger. A watcher on the packaged migration
directory cannot distinguish a bypassed `pacman -Syu` from the package
transaction inside a normal `magikos update`, so it fired notifications for
migrations that `magikos-migrate` was about to apply in the visible update
terminal. The retired unit was `magikos-update-user-notify.path`.

Retiring that watcher through a migration cannot come in time for the update
that retires it: pacman writes the migration directory, the watcher fires, and
only then does `magikos-migrate` reach the migration that stops it. So the
notifier also refuses to run while `magikos update` holds its
`$XDG_RUNTIME_DIR/magikos-update.lock`, which covers the stale watcher and any
trigger added later — during an update, every pending migration is by
definition already being applied a step away. It checks again after waiting for
the notification server, since that wait is long enough for an update to start
underneath it.

The notifier reads only its own user's runtime directory, never the `/tmp` path
`magikos-update` falls back to when `XDG_RUNTIME_DIR` is unset. A shared lock
file belongs to whoever created it first, so honouring it would let one user
silence another user's notification. Missing an update and showing a redundant
toast is the better failure.

Suppression is why `magikos-update-stay-awake` starts its sleep inhibitor with
the lock descriptor closed. That inhibitor outlives the step that starts it, so
an update killed before cleanup would otherwise leave it holding the flock
indefinitely — blocking later updates and, now that the notifier reads the same
lock, silencing migration notifications at every login.

Fallbacks:

- `magikos-provision-first-run` enables `magikos-migrate-notify.service`, which also
  covers users created after install: their per-user migration markers are
  missing, so their first login prompts them to run every shipped migration.
- The package ships `magikos-update-user-notify.service` as a symlink onto
  `magikos-migrate-notify.service`. Users set up before the rename hold an
  absolute `graphical-session.target.wants` symlink to the old path, and the
  migration that repoints it only runs for users who run an update — the
  opposite of who the notifier is for. The alias can be dropped once installs
  have run migration `1785095882`.
- The notifier is ordered after `graphical-session.target`, so an action that
  launches through `uwsm-app` cannot block the target that gates UWSM's app
  daemon.
- The notifier waits for a live notification server before sending, because
  `graphical-session.target` can be reached before the shell claims
  `org.freedesktop.Notifications`.
- The notifier is only a prompt. It does not run migrations in the background.
- A session that is already open when another user updates is not re-checked;
  it picks the migrations up at its next login, or whenever that user runs
  `magikos-migrate` or `magikos update`.
- Direct pacman updates do not run `magikos-hook post-update` unless the user
  explicitly runs that hook; without a package-update marker, the only pending
  state we can derive is missing per-user migration markers.

## Shell update indicator

The bar widget `magikos.system-update` runs:

```bash
magikos-update-available
```

`magikos-update-available` checks the active Magikos sources for updates:

- new upstream commits for the active dev-linked checkout
- `magikos-dev`, when installed
- otherwise `magikos`, when installed

The dev check fetches the checkout's configured upstream before comparing it
with `HEAD`. A failed fetch is quiet and falls back to the existing remote-
tracking state.

Exit codes:

- `0` — Magikos updates are available; stdout is the update list.
- non-zero — no Magikos updates are available; stdout says Magikos is up to date.

The widget runs this check on shell startup and every six hours. Clicking the
update icon launches `magikos-update` in a floating terminal.

## Channels and versions

Updates install whatever the active channel points at. `magikos-channel-set
<stable|rc|edge|dev>` switches channels: the three package channels select
which pacman repo the mirrorlist points at (and swap between the `magikos` and
`magikos-dev` packages through a guard-allowed pacman run), while `dev` links
the runtime to a git checkout via the dev-link mechanism, after which
`magikos update` fast-forwards that checkout instead of upgrading a package.

There is no version file at runtime. `magikos-version` derives the version from
`pacman -Q` on whichever package is installed, or reports `dev (<hash>)` for a
linked checkout, and `magikos-version-channel` sniffs the mirrorlist and
pacman.conf to answer which channel is active.

## Update-related binaries

This inventory is intentionally opinionated. Some commands are useful as stable
leaf commands; others exist mostly because the old update flow accreted small
scripts.

| Binary | Current purpose | Keep? / Question |
| --- | --- | --- |
| `magikos-update` | Public user command. Adds transcript logging, confirmation, snapshot, and restart checks around the locked, sleep-inhibited update pipeline. | **Keep.** This is the blessed entry point and orchestrates the update pipeline. |
| `magikos-update-lock` | Hidden command wrapper that holds the per-user update lock while its child runs. | **Keep internal/hidden.** Isolates update concurrency and lock descriptor handling. |
| `magikos-update-stay-awake` | Hidden helper that starts or stops update-owned sleep and idle inhibition, restoring only the state it changed. | **Keep internal/hidden.** Keeps inhibitor ownership and cleanup together. |
| `magikos-update-status` | Hidden helper that refreshes or clears the shell update indicator after rechecking available updates. | **Keep internal/hidden.** Keeps shell status synchronization out of the main pipeline. |
| `magikos-update-confirm` | Gum confirmation copy for `magikos update`. | **Question.** Could be inlined into `magikos-update`; separate file only helps keep copy isolated. |
| `magikos-update-dev` | Fast-forwards the active dev-linked checkout from its configured upstream; no-ops for package-backed installs. | **Keep.** Runs before package updates so a checkout conflict stops the update before system mutation. |
| `magikos-update-keyring` | Ensures Magikos keyring and Arch keyring are current before the main transaction. | **Keep, but review.** It uses targeted `pacman -Sy` for keyring bootstrapping; acceptable for this special case but should remain tightly scoped. |
| `magikos-update-system-pkgs` | Runs `sudo env MAGIKOS_UPDATE_PACMAN=1 pacman -Syu --noconfirm` with `--overwrite '/usr/share/magikos/*'`, capturing stderr to a report file; on failure it execs `magikos-update-system-pkgs-when-conflicted`. | **Keep for now.** Small leaf command, clear/testable. |
| `magikos-update-system-pkgs-when-conflicted` | Hidden conflict handler: quarantines unowned conflicting files under `/var/lib/magikos/replaced`, retries the upgrade once, restores files the upgrade didn't claim, and hands package-vs-package conflicts to an interactive pacman run (never under `-y`). | **Keep internal/hidden.** Keeps conflict recovery out of the happy path. |
| `magikos-update-pkg-prune` | Trims the pacman cache to two versions per package (`paccache -rk2`) before the snapshot, keeping the offline downgrade path while capping snapshot growth. | **Keep internal/hidden.** |
| `magikos-update-requires-free-space` | Aborts the update below a 10 GiB free-space threshold on `/`; silently skipped when free space cannot be determined; `MAGIKOS_UPDATE_FORCE=1` bypasses. | **Keep internal/hidden.** |
| `magikos-migrate` | Public migration command. Waits for pacman, then runs all pending migrations for the current user. Supports `--pending`. | **Keep.** This replaces the discarded `magikos-update-user-finalize` name and no longer needs `--force`. |
| `magikos-update-pacman-guard` | ALPM pre-transaction guard that aborts direct `pacman -Syu` style upgrades unless Magikos set `MAGIKOS_UPDATE_PACMAN=1` or the user explicitly set `MAGIKOS_ALLOW_DIRECT_PACMAN=1`. | **Keep internal/hidden.** This is what nudges users back to `magikos update`. |
| `magikos-migrate-notify` | Internal login-time notification helper. Uses `magikos-migrate --pending` and shows a notification only when this user has pending migrations. | **Keep internal/hidden.** Clear name now that the public command is `magikos-migrate`. |
| `magikos-update-user-notify` | Hidden compatibility wrapper for `magikos-migrate-notify`. | **Temporary.** Keep only for old callers. |
| `magikos-update-available` | Update checker for shell widget and post-update refresh. | **Keep.** Could eventually be renamed `magikos-update-check`, but current name matches widget semantics. |
| `magikos-update-aur-pkgs` | Updates AUR packages with `yay -Sua` if foreign packages exist and AUR is reachable. | **Question.** Magikos is package-backed now, but users may still install AUR packages. Keep for now. |
| `magikos-update-mise` | Runs `MISE_MINIMUM_RELEASE_AGE=0 mise up` for mise-managed tools — the override of mise's release-age cooldown is the point. | **Keep.** Mise-managed tools are intentionally part of the blessed update path. |
| `magikos-update-orphan-pkgs` | Lists orphans and prompts before removal; noninteractive mode never removes. | **Keep for now.** Safe because it is prompt-only. |
| `magikos-update-analyze-logs` | Scans `/tmp/magikos-update.log` for known failure patterns, currently initramfs generation. | **Keep/expand.** Useful safety net; should grow only for high-signal checks. |
| `magikos-update-restart` | Prompts for reboot after kernel/Hyprland updates, restarts components with `restart-*-required` markers, and always restarts the shell. | **Keep.** Important final step; may eventually include service-restart checks. |
| `magikos-update-firmware` | Manual firmware update command using fwupd. Not part of the normal update pipeline. | **Keep separate.** Firmware is not a routine system update step. |
| `magikos-update-time` | Restarts `systemd-timesyncd`. | **Question.** Not really an update command. Consider renaming/moving under system/time maintenance. |

## Closed decisions

1. **Migrations run per-user from the update pipeline**
   - `magikos update` runs `magikos-migrate` after pacman finishes.
   - Package-time migration runners do not apply migrations inside pacman.
   - Every user has per-user migration markers, and migrations must be
     idempotent when they repair machine-wide state.

2. **Migration notification naming**
   - The real helper is `magikos-migrate-notify`, started by
     `magikos-migrate-notify.service`.
   - `magikos-update-user-notify` remains only as a hidden compatibility wrapper.

3. **Update pipeline ownership**
   - `magikos-update` owns the full update pipeline now.

4. **Mise remains in the blessed update path**
   - `magikos-update-mise` intentionally runs as part of `magikos update`.

5. **Orphan cleanup stays in the update path for now**
   - It is prompt-only and never removes packages noninteractively.

6. **Direct pacman user follow-up is based on actual migration state**
   - Direct `sudo pacman -Syu` no longer uses a fake user-update marker.
   - User notifications are shown only when `magikos-migrate --pending` finds
     missing per-user migration state.

## Remaining concerns

1. **Pacman guard scope**
   - The guard detects direct pacman sysupgrade invocations and allows Magikos
     commands that set `MAGIKOS_UPDATE_PACMAN=1`.
   - We may regret blocking some legitimate package-manager frontends or
     maintenance flows. Keep an eye on what should be allowed versus redirected
     to `magikos update`.

2. **Pacnew/pacsave handling is still missing**
   - Package-backed Magikos should warn about or help process `.pacnew` and
     `.pacsave` files after updates.
