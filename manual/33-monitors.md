# Monitors

Magikos assumes you're running on a 2x-capable retina-class display by default. This is what you need to get those nice, crisp programmer fonts. It's what almost all new premium laptops with high-resolution screens are optimized for. It's what you'd want to run on a 27" 5K [Apple Studio Display](https://www.apple.com/studio-display/)/[ProArt PA27JCV](https://www.asus.com/us/displays-desktops/monitors/proart/proart-display-5k-pa27jcv/)/[Samsung S9](https://www.samsung.com/us/computing/monitors/5k/27-viewfinity-s9-5k-monitor-with-thunderbolt-4-matte-display-and-smart-features-ls27c900panxza/)/[Kuycon G27P](https://kuycon.us/monitors/G27P/) or 32" 6K [Apple XDR](https://www.apple.com/pro-display-xdr/)/[ProArt PA32QCV](https://www.asus.com/displays-desktops/monitors/proart/proart-display-6k-pa32qcv/)/[Kuycon G32P](https://kuycon.us/monitors/G32P/).

But if you're not running a display with a PPI of 218 or above, you'll want to change the monitor settings. For example, if you have a 27" or 32" 4K, you can use fractional scaling by opening `~/.config/sway/output.conf` (via _Setup > Monitors_ in the Magikos menu) and setting the scale for your display:

```
output DP-1 scale 1.6
```

If you're using a 1080p or 1440p display, you'll probably just want to use 1x scaling, so you can use:

```
output DP-1 scale 1
```

Scaling changes apply right away, but applications that were already running may need to be restarted to pick up the new size. So make sure you quit any windows that look off after the change (or close all windows with `Ctrl + Alt + Del`!).

You can also quickly step through the major monitor scaling ratios (1x, 1.25x, 1.6x, 2x, 3x, 4x) using `Super + /` to go higher and `Super + Alt + /` to go lower. If you have the default configuration, these changes will also persist past reboot.

### Making text bigger or smaller

Monitor scaling changes the size of everything. If all you want is bigger or smaller _text_, there's a single knob for that:

```
magikos display text size 14
```

That takes a pixel size between 9 and 20, and moves the Magikos shell, GTK applications, and your terminal together, so the whole desktop stays in proportion. Run it without an argument to see where you're at, and `magikos display text size reset` to go back to the default. Foot is the one straggler: it has no way to reload its config, so running terminals keep their old size until you open a new one.

### Extending and mirroring laptop displays

When you connect an external screen to your laptop, the display is automatically extended. But you can change that to mirroring instead using _Trigger > Hardware_ in the Magikos menu or `Super + Ctrl + Alt + Delete`. This is especially helpful if that external screen is a projector, and you want to show something while working.

When you're extending, closing the lid on the laptop will automatically turn off the internal screen. Opening the lid will turn it back on. You can also control this manually using _Trigger > Hardware_ in the Magikos menu or `Super + Ctrl + Delete`.

### Arranging multiple screens

Sway works great with multiple screens. Read more about how to lay them out in the `sway-output(5)` man page. You can bind specific workspaces to specific monitors with a `workspace <number> output <name>` line as well. In Magikos, these rules go in `~/.config/sway/output.conf` — the file ships with commented examples for pinning a specific monitor to a resolution, position, and rotation.

### Controlling brightness

Monitor brightness is controlled by the dedicated function keys for brightness up/down. If you hold down shift while pressing these, you'll go to maximum or minimum brightness. The keys control the display you're focused on, so external monitors that speak DDC/CI are adjusted the same way as the laptop screen.

### Apple Displays

If you're using an Apple display, the regular keyboard brightness keys will also automatically work, if you're focused on the Apple display. This is done through the `asdcontrol` command.

Note that if you're using an Apple 6K XDR display, you may see a phantom screen in your `swaymsg -t get_outputs` listing. You can turn this off with an `output DP-2 disable` line via _Setup > Monitors_.

On Intel machines, you should be connecting to Apple displays using a regular Thunderbolt cable. On other machines without Thunderbolt, you'll typically have to use a [DP + USB-A -> USB-C cable](https://www.amazon.com/dp/B0BNX7MS6N) to make it work.
