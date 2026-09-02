# Setup user theme folder and seed the default only when no theme exists yet.
mkdir -p ~/.config/magikos/themes

if [[ ! -s $HOME/.local/state/magikos/current/theme.name ]]; then
  # iso-chroot and provision-owner both run without a live session to notify.
  if [[ ${MAGIKOS_SETUP_CONTEXT:-runtime} != "runtime" ]]; then
    MAGIKOS_THEME_HEADLESS=1 magikos-theme-set "Tokyo Night"
    rm -f ~/.config/chromium/SingletonLock # otherwise archiso owns the Chromium singleton
  else
    magikos-theme-set "Tokyo Night"
  fi
fi
magikos-theme-set-pi --activate

# Seed the wallpaper set so sway's fallback bg path resolves.
mkdir -p ~/Pictures/Wallpapers
for wallpaper in "$MAGIKOS_PATH"/wallpapers/*; do
  [[ -f $wallpaper ]] || continue
  cp -n "$wallpaper" ~/Pictures/Wallpapers/ 2>/dev/null || true
done

# Expose the same set through the shell style menu, which lists the active
# theme's user background folder alongside the theme's stock backgrounds.
CURRENT_THEME=$(cat "$HOME/.local/state/magikos/current/theme.name" 2>/dev/null || echo tokyo-night)
mkdir -p "$HOME/.config/magikos/backgrounds/$CURRENT_THEME"
for wallpaper in "$MAGIKOS_PATH"/wallpapers/*; do
  [[ -f $wallpaper ]] || continue
  cp -n "$wallpaper" "$HOME/.config/magikos/backgrounds/$CURRENT_THEME/" 2>/dev/null || true
done

mkdir -p ~/.config/btop/themes
ln -snf "$HOME/.local/state/magikos/current/theme/btop.theme" ~/.config/btop/themes/current.theme
