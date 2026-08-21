# Themes, Backgrounds, and Fonts

Read this before changing themes, backgrounds, fonts, or theme colors.

## Theme Commands

```bash
magikos theme list              # Show available themes
magikos theme current           # Show current theme
magikos theme set <name>        # Apply theme ("Tokyo Night" and "tokyo-night" both work)
magikos theme bg next           # Cycle background
magikos theme install <url>     # Install from git repo
```

## Making a New Theme

1. Create a directory under `~/.config/magikos/themes`.
2. See how an existing theme is done via `/usr/share/magikos/themes/catppuccin`.
3. Download a matching background (or several) from the internet and put them in `~/.config/magikos/themes/<name-of-new-theme>/backgrounds/`.
4. When done with the theme, run `magikos theme set "Name of new theme"`.

Additional user backgrounds for any theme (stock or custom) go in
`~/.config/magikos/backgrounds/<theme-slug>/`.

## Customizing a Stock Theme

Never edit stock themes under `/usr/share/magikos/themes/` — changes are lost
on update. Two safe options:

**Overlay (preferred for small tweaks):** create a user theme directory with
the SAME slug containing only the files you want to change. When the theme is
applied, the stock theme is copied first and your files win on top:

```bash
mkdir -p ~/.config/magikos/themes/catppuccin
cp /usr/share/magikos/themes/catppuccin/colors.toml ~/.config/magikos/themes/catppuccin/
# Edit the copied colors.toml, then re-apply:
magikos theme set catppuccin
```

**Fork:** copy the whole stock theme under a new name for a fully independent
variant:

```bash
cp -r /usr/share/magikos/themes/catppuccin ~/.config/magikos/themes/catppuccin-custom
# Edit ~/.config/magikos/themes/catppuccin-custom/, then:
magikos theme set catppuccin-custom
```

## Fonts

```bash
magikos font list               # Available fonts
magikos font current            # Current font
magikos font set <name>         # Change font
```
