# Keyboard, Mouse, Trackpad

Sway lets you configure all your inputs in great detail. You can change the keyboard repeat to be supersonically fast or make the trackpad use natural scrolling. You change all of it in `~/.config/sway/input.conf`, which you can also reach via _Setup > Input_ in the Magikos menu (`Super + Space`). Anything you set there replaces Magikos's defaults.

Here's an example:

```
input type:keyboard {
  # Use multiple keyboard layouts and switch between them with Left Alt + Right Alt
  xkb_layout us,dk
  xkb_options compose:caps,shift:both_capslock_cancel,grp:alts_toggle

  # Change speed of keyboard repeat
  repeat_rate 40
  repeat_delay 600
}

# Increase sensitivity for mouse/trackpad (range: -1 to 1)
input type:pointer accel_profile flat
input type:pointer pointer_accel 0.35

input type:touchpad {
  # Use natural (inverse) scrolling
  natural_scroll enabled

  # Use two-finger clicks for right-click instead of lower-right corner
  click_method clickfinger

  # Control the speed of your scrolling
  scroll_factor 0.3
}
```

You can [see all the input options](https://man.archlinux.org/man/sway-input.5.en) on the sway-input man page.

By default, Magikos uses CapsLock as the compose key for [quick emojis](07-hotkeys.md#quick-emojis) and [other completions](07-hotkeys.md#quick-completions). If you'd rather use CapsLock as Caps Lock, move the compose key elsewhere by changing `compose:caps` in `xkb_options`. For example, this moves the compose key to Right Alt:

```
input type:keyboard {
  xkb_options compose:ralt
}
```

On Dell XPS laptops with a haptic touchpad, you can also set the click strength to low, mid, or high under _Trigger > Hardware > Touchpad Haptics_.

### Typing in Chinese, Japanese, and other languages

Magikos runs the [fcitx5](https://fcitx-im.org/) input method framework as part of every session — it's what powers the CapsLock compose sequences. That means the plumbing for non-Latin input is already in place: install an input engine like `fcitx5-mozc` (Japanese) or `fcitx5-chinese-addons` (Chinese) with `magikos pkg add`, plus `fcitx5-configtool` to add the engine to your input methods and set the key that switches between them.

### Use ALT as SUPER

On some keyboards, it's not convenient to use the primary meta key (Windows/cmd key) as SUPER. You can change this to be ALT instead using this change:

```
input type:keyboard {
  xkb_options compose:caps,shift:both_capslock_cancel,altwin:swap_alt_win
}
```
