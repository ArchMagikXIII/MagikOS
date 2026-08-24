---
name: magikos
description: >
  REQUIRED for end-user customization of Linux desktop, window manager, or system config.
  Use when editing ~/.config/sway/, ~/.config/magikos/,
  ~/.config/alacritty/, ~/.config/foot/, ~/.config/kitty/, or ~/.config/ghostty/.
  Triggers: Sway, window rules, keybindings, monitors, gaps, borders,
  blur, opacity, magikos-shell, bar, terminal config, themes, background,
  night light, idle, lock screen, screenshots, reminders, output config,
  workspace settings, display config, and user-facing magikos commands. Excludes Magikos
  source development through `magikos dev link` workflows.
---

# Magikos Skill

Manage [Magikos](https://magikos.org/) Linux systems - a beautiful, modern, opinionated Arch Linux distribution with Sway.

This skill is for end-user customization on installed systems.
It is not for contributing to Magikos source code.

## When This Skill MUST Be Used

**ALWAYS invoke this skill for end-user requests involving ANY of these:**

- Editing ANY file in `~/.config/sway/` (keybindings, outputs, input devices, etc.)
- Editing `~/.config/magikos/shell.json` (status bar layout, widgets)
- Editing terminal configs (alacritty, foot, kitty, ghostty)
- Editing ANY file in `~/.config/magikos/`
- Window behavior, opacity, blur, gaps, borders
- Window rules, workspace settings, display/output configuration
- Themes, backgrounds, fonts, appearance changes
- User-facing `magikos` commands (`magikos theme ...`, `magikos refresh ...`, `magikos restart ...`, etc.)
- Screenshots, screen recording, reminders, night light, idle behavior, lock screen

**If you're about to edit a config file in ~/.config/ on this system, STOP and use this skill first.**

**Do NOT use this skill for Magikos development tasks** (editing the Magikos source tree, creating migrations, or running `magikos dev ...` workflows).

## Topic Guides

Deeper instructions for common areas live next to this file. Read the
matching guide before starting:

- [`plugins.md`](plugins.md) - the Magikos shell: bar layout, widgets, plugins, idle behavior
- [`theming.md`](theming.md) - themes, backgrounds, and fonts
- [`hooks.md`](hooks.md) - automation hooks that run on system events
- [`capture.md`](capture.md) - screenshots, screen recordings, OCR text capture, and file sharing
- [`contributing.md`](contributing.md) - reporting Magikos bugs and submitting fixes upstream

## Critical Safety Rules

For privileged commands, follow the Privilege Escalation rules below: `sudo` when a terminal is available for the password prompt, `pkexec` when it is not. Do not wrap commands that already manage privilege elevation themselves.

**For end-user customization tasks, NEVER modify anything in `/usr/share/magikos/`** - but READING is safe and encouraged.

This directory is owned by the magikos package. Any local changes will be
overwritten on the next `magikos update`.

```
/usr/share/magikos/     # READ-ONLY - NEVER EDIT (reading is OK)
├── bin/                    # Command source (packaged binaries are on PATH)
├── config/                 # Default config templates
├── themes/                 # Stock themes
├── default/                # System defaults
├── shell/                  # Magikos shell source and defaults
├── migrations/             # Update migrations
└── install/                # Installation scripts
```

**Reading `/usr/share/magikos/` is SAFE and useful** - do it freely to:
- Understand how magikos commands work: `magikos theme set --help` or `cat $(which magikos-theme-set)`
- See default configs before customizing: `cat "$MAGIKOS_PATH/config/magikos/shell.json"`
- Reference default Sway settings: `cat "$MAGIKOS_PATH"/config/sway/*.conf`
- Check stock theme files to copy for customization

**Always use these safe locations instead:**
- `~/.config/` - User configuration (safe to edit)
- `~/.config/magikos/themes/<custom-name>/` - Custom themes
- `~/.config/magikos/hooks/` - Custom automation hooks

If the request is to develop Magikos itself, this skill is out of scope. Follow repository development instructions instead of this skill.

## Privilege Escalation

For an interactive script or command run in a visible terminal, use `sudo` for
privileged work. Magikos may grant passwordless `sudo` access to particular
commands, and the terminal is the appropriate place to request a password
when one is needed.

Use `pkexec` only when the caller cannot interact with a terminal or cannot
enter a password there, such as a command launched by an agent or a graphical
background process. Do not replace `sudo` with `pkexec` merely because a
command changes system state.

## System Architecture

Magikos is built on:

| Component | Purpose | Config Location |
|-----------|---------|-----------------|
| **Arch Linux** | Base OS | `/etc/`, `~/.config/` |
| **Sway** | Wayland compositor/WM | `~/.config/sway/` |
| **Magikos shell** | Status bar + notifications (Quickshell) | `~/.config/magikos/shell.json` |
| **Launcher/menus** | Quickshell menu | `~/.config/magikos/extensions/magikos-menu.jsonc` |
| **Alacritty/Foot/Kitty/Ghostty** | Terminals | `~/.config/<terminal>/` |
| **Magikos OSD** | On-screen display | Quickshell plugin |

## Command Discovery

Magikos ships a single `magikos` CLI that dispatches to all `magikos-*` binaries via `magikos <group> <action>`. Always prefer this form — it is self-documenting and stable. The underlying `magikos-*` binaries still exist on `PATH` and remain safe to read for source.

```bash
# List every documented command and its summary (--all includes hidden commands)
magikos commands

# Show the commands inside a group
magikos theme --help
magikos refresh --help
magikos restart --help

# Show help for a specific command (does not execute it)
magikos theme set --help

# Machine-readable listing (binary, route, summary, args, aliases)
magikos commands --json

# Read a command's source to understand it
cat $(which magikos-theme-set)
```

### Command Groups

Run `magikos --help` for the full list. The most common groups:

| Group | Purpose | Example |
|-------|---------|---------|
| `magikos refresh` | Reset config to defaults (backs up first) | `magikos refresh shell` |
| `magikos restart` | Restart a service/app | `magikos restart shell` |
| `magikos toggle` | Toggle feature on/off | `magikos toggle nightlight` |
| `magikos theme` | Theme management | `magikos theme set <name>` |
| `magikos bar` | Bar layout and widgets | `magikos bar move magikos.clock --section right` |
| `magikos plugin` | Manage/clone shell plugins | `magikos plugin clone magikos.clock` |
| `magikos hook` | Install automation hooks | `magikos hook install theme-set <script>` |
| `magikos install` | Install optional software / packages | `magikos install docker dbs` |
| `magikos launch` | Launch apps | `magikos launch browser` |
| `magikos capture` | Screenshots and recordings | `magikos capture screenshot` |
| `magikos reminder` | Desktop notification reminders | `magikos reminder 15 "Pickup Jack"` |
| `magikos pkg` | Package management | `magikos pkg add <pkg>` |
| `magikos setup` | Interactive setup wizards | `magikos setup security fingerprint` |
| `magikos update` | System updates | `magikos update` |

## Configuration Locations

Sway config lives in `~/.config/sway/` (`bindings.conf`, `input.conf`,
`output.conf`, and friends).
The Magikos shell (bar, notifications, plugins, idle) is configured in
`~/.config/magikos/shell.json` — see [`plugins.md`](plugins.md).

### Terminals

```
~/.config/alacritty/alacritty.toml
~/.config/foot/foot.ini
~/.config/kitty/kitty.conf
~/.config/ghostty/config
```

**Command:** `magikos restart terminal`

### Other Configs

| App | Location |
|-----|----------|
| btop | `~/.config/btop/btop.conf` |
| fastfetch | `/etc/fastfetch/config.jsonc` default; `~/.config/fastfetch/config.jsonc` user override |
| lazygit | `~/.config/lazygit/config.yml` |
| git | `~/.config/git/config` |

## Safe Customization Patterns

### Edit User Config Directly

For simple changes, edit files in `~/.config/`:

```bash
# 1. Read current config
cat ~/.config/sway/bindings.conf

# 2. Backup before changes
cp ~/.config/sway/bindings.conf ~/.config/sway/bindings.conf.bak.$(date +%s)

# 3. Make changes with Edit tool

# 4. Apply changes
# - Sway: auto-reloads configs on save, but MUST validate with `swaymsg reload`
# - Magikos shell: shell.json and user plugin code under ~/.config/magikos/plugins/ hot-reload on save
# - Menus/launcher: ~/.config/magikos/extensions/magikos-menu.jsonc hot-reloads on save
# - Terminals: apply with `magikos restart terminal` (reloads running terminals; foot picks changes up in new windows)
```

### Reset to Defaults -- ALWAYS SEEK USER CONFIRMATION BEFORE RUNNING

When customizations go wrong:

```bash
# Reset specific config (creates backup automatically)
magikos refresh shell
magikos refresh sway

# The refresh command:
# 1. Backs up current config with timestamp
# 2. Copies default from $MAGIKOS_PATH/config/
# 3. Restarts the component where the refresh needs it (e.g. `refresh shell`)
```

## System Commands

```bash
magikos update                  # Full system update
magikos version                 # Show Magikos version
magikos debug --no-sudo --print # Debug info (ALWAYS use these flags)
magikos system lock             # Lock screen
magikos system shutdown         # Shutdown
magikos system reboot           # Reboot
```

**IMPORTANT:** Always run `magikos debug` with `--no-sudo --print` flags to avoid interactive sudo prompts that will hang the terminal.

## Troubleshooting

```bash
# Get debug information (ALWAYS use these flags to avoid interactive prompts)
magikos debug --no-sudo --print

# Reset specific config to defaults
magikos refresh <app>

# Refresh specific config file
# config-file path is relative to ~/.config/
# eg. `magikos refresh config sway/bindings.conf` will refresh ~/.config/sway/bindings.conf
magikos refresh config <config-file>

# Full reinstall of configs (nuclear option)
magikos reinstall
```

## Decision Framework

When user requests system changes:

1. **Is it a stock magikos command?** Use it directly
2. **Is it a config edit?** Edit in `~/.config/`, never `/usr/share/magikos/`
3. **Is it a theme customization?** Follow [`theming.md`](theming.md); create a NEW custom theme directory
4. **Is it automation?** Follow [`hooks.md`](hooks.md); use `magikos hook install` and the hook `.d` directories
5. **Is it a package install?** Use `magikos pkg add <pkgs...>` (or `magikos pkg aur add <pkgs...>` for AUR-only packages)
6. **Is it built-in shell/plugin code?** Follow [`plugins.md`](plugins.md); clone it with `magikos plugin clone`, never edit the packaged copy
7. **Unsure if command exists?** Run `magikos commands` (or `magikos <group> --help` for one group)

### Reminder Requests

When the user asks to set a reminder, use `magikos reminder <minutes> [message]` directly. Convert natural language durations to minutes and title-case short reminder labels when appropriate.

```bash
magikos reminder 15 "Pickup Jack"
magikos reminder 60 "Check laundry"
magikos reminder show
magikos reminder clear
```

## Out of Scope

This skill intentionally does not cover Magikos source development. Do not use this skill for:
- Editing files in `/usr/share/magikos/` (`bin/`, `config/`, `default/`, `shell/`, `themes/`, `migrations/`, etc.)
- Creating or editing migrations
- Running `magikos dev ...` commands

## Example Requests

- "Change my theme to catppuccin" -> `magikos theme set catppuccin`
- "Add a keybinding for Super+E to open file manager" -> Check existing bindings first, then add a `bindsym` line in `~/.config/sway/bindings.conf`
- "Configure my external monitor" -> Edit `~/.config/sway/output.conf`
- "Make the window gaps smaller" -> Edit `~/.config/sway/appearance.conf`
- "Turn on night light" -> `magikos toggle nightlight`
- "Set a reminder to pickup jack in 15 minutes" -> `magikos reminder 15 "Pickup Jack"`
- "Show my reminders" -> `magikos reminder show`
- "Clear all reminders" -> `magikos reminder clear`
- "Customize the catppuccin theme colors" -> Overlay: put an edited `colors.toml` in `~/.config/magikos/themes/catppuccin/`, then re-apply the theme (see `theming.md`)
- "Run a script every time I change themes" -> Install it with `magikos hook install theme-set <script>`
- "Change how workspace labels are rendered" -> Clone `magikos.workspaces`, which switches the bar to `<username>.workspaces`, then edit the clone
- "Lock after ten minutes" -> Set `idle.lock` to `600` in `~/.config/magikos/shell.json`
- "Reset shell/bar to defaults" -> `magikos refresh shell`
- "Record my screen" -> `magikos screenrecord --fullscreen`, then `magikos screenrecord --stop-recording` (see `capture.md`)
- "Report this bug to Magikos" -> Gather diagnostics and a capture of the problem, then file it (see `contributing.md`)
