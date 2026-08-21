# Automation Hooks

Read this before setting up scripts that run on system events (theme changes,
updates, boot, low battery, etc.).

Hooks live in `~/.config/magikos/hooks/<name>.d/` — one directory per event,
holding any number of independent scripts. Install with
`magikos hook install <name> <script>` (copies the script in and makes it
executable). The runner also executes a flat `~/.config/magikos/hooks/<name>`
file first, if one exists.

```
~/.config/magikos/hooks/
├── battery-low.d/          # Low battery (percentage in $1)
├── font-set.d/             # After font change (font name in $1)
├── post-boot.d/            # After the desktop starts
├── post-update.d/          # During `magikos update`, after system packages and migrations
├── pre-refresh-pacman.d/   # Before `magikos refresh pacman` re-syncs packages
└── theme-set.d/            # After theme change (theme slug in $1)
```

Example hook script:
```bash
#!/bin/bash
THEME_NAME=$1
echo "Theme changed to: $THEME_NAME"
# Add custom actions here
```
