# Magikos Shell: Bar, Plugins, and Idle

Read this before changing the status bar, notifications, shell plugins,
widgets, or idle/lock behavior.

The bar, notification daemon, settings panel, and assorted overlays all run
inside a single long-running Quickshell process (`magikos-shell`).

```
~/.config/magikos/shell.json             # User overrides: bar, plugins, idle
~/.config/magikos/plugins/<plugin-id>/   # User-owned shell plugins
$MAGIKOS_PATH/config/magikos/shell.json  # Canonical defaults
```

The shell hot-reloads `shell.json` on save — no restart needed for layout
changes. `idle.screensaver` and `idle.lock` are seconds since user idle began.

**Commands:** `magikos restart shell`, `magikos refresh shell`

## Bar Layout

Use the `magikos bar` group to move and manage widgets:

```bash
magikos bar move magikos.clock --section right
```

For layout edits beyond what the commands cover, edit the bar configuration
in `~/.config/magikos/shell.json`; it hot-reloads on save.

## Customizing Built-In Plugins and Widgets

To customize a built-in bar widget, never edit `$MAGIKOS_PATH/shell/plugins/`.
Clone it into the user plugin directory instead:

```bash
magikos plugin clone magikos.workspaces
# Edit ~/.config/magikos/plugins/<username>.workspaces/; saved changes reload automatically.
```

Cloning switches the bar to the cloned copy (e.g. `<username>.workspaces`),
which is yours to edit and survives updates.

Saving a file anywhere under `~/.config/magikos/plugins/` reloads plugin code
automatically. If a change somehow fails to apply, force a reload with
`magikos-shell shell rescanPlugins`.

## Idle and Lock

Set `idle.screensaver` and `idle.lock` in `~/.config/magikos/shell.json`,
in seconds since user idle began. Example: "lock after ten minutes" means
setting `idle.lock` to `600`.
