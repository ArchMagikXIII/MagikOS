# Real newlines, not a literal \n: the card renders the body as it arrives, and
# elides past three lines.
magikos-notification-send -u critical -g  "Learn Keybindings" \
  $'Super + K for cheatsheet.\nSuper + Space for Magikos Menu.' \
  --exec magikos-menu-keybindings
