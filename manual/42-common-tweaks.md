# Common tweaks

This is a collection of common tailorings to the Magikos setup. Know that it might occasionally be necessary for system updates to restore certain configs to their original condition. If this happens, your changes won't be lost, but put in a `.bak` file in the same directory.

If you screw something up, you can restore individual configs to their original setup via _Update > Config_ in the Magikos menu. If you _really_ screw everything up, you can reset all configs via `magikos-reinstall`.

### Reveal all tray icons all the time

By default, tray icons, like Dropbox, 1password, or Steam, are hidden behind the tray expander arrow, which reveals them when you hover it. If you'd like to have them exposed all the time, right-click the expander arrow to open the tray icon manager, then pin the icons you want to keep visible (you can also hide the ones you never want to see).

### Remove window gaps

On laptop displays, some people prefer not to waste any pixels on window gaps (or even a top bar, which you can toggle off with `Super + Shift + Space`). You can toggle all gaps and borders off with `Super + Shift + Backspace`, or remove them permanently by adding this to `~/.config/sway/appearance.conf`:

```
gaps inner 0
gaps outer 0
default_border pixel 0
```
