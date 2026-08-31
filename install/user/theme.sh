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

# Seed the default sway wallpaper so the fallback bg path resolves.
LOGO_WALLPAPER="$MAGIKOS_PATH/Logo-Wallpaper.png"
if [[ -f $LOGO_WALLPAPER ]]; then
  mkdir -p ~/Pictures/Wallpapers
  cp -n "$LOGO_WALLPAPER" ~/Pictures/Wallpapers/Logo-Wallpaper.png 2>/dev/null || true
fi

mkdir -p ~/.config/btop/themes
ln -snf "$HOME/.local/state/magikos/current/theme/btop.theme" ~/.config/btop/themes/current.theme
