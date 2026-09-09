# Magikos CLI

Magikos is usually controlled through the hotkeys and the Magikos menu (`Super + Space`). But you can also control it through the `magikos` CLI. This is particularly helpful when you're having an AI agent work with you on customization or configuration.

The CLI has access to all the internal tooling that is used both via the menu and otherwise. You can see everything that's available by running `magikos` in the terminal.

It looks something like this:

```
~ ❯ magikos
Magikos command center

Usage:
  magikos <command> [args...]
  magikos commands [--all] [--json] [--check]
  magikos <group> --help
  magikos <group> <command> --help

Common commands:
  magikos update              Update Magikos and system packages
  magikos theme list          List available themes
  magikos theme set <name>    Apply a theme
  magikos font list           List available fonts
  magikos screenshot          Take a screenshot
  magikos debug               Print debugging information

Groups:
  agent          AI coding agent usage data
  audio          Audio input and output controls
  bar            Magikos shell bar layout and settings
  battery        Battery status helpers
  bluetooth      Bluetooth device controls
  branch         Magikos git branch management
  branding       About and screensaver branding
  brightness     Display and keyboard brightness
  capture        Screenshots and screen recording
  channel        Magikos release channel management
  clipboard      Clipboard helpers
  cmd            Command and shortcut helpers
  config         System configuration helpers
  debug          Diagnostics and support logs
  ...
```

And you can dive deeper on every group:

```
~ ❯ magikos capture
Capture commands — Screenshots and screen recording:
  magikos capture qr                                                                                                                                                                                                       Decode a QR code from a screenshot region
  magikos capture screenrecording [--fullscreen] [--with-desktop-audio] [--with-microphone-audio] [--with-webcam] [--webcam-device=<device>] [--webcam-size=<small|medium|large>] [--resolution=<size>] [--stop-recording]  Start or stop screen recording
  magikos capture screenrecording with webcam                                                                                                                                                                              Pick a webcam and start a screen recording with it
  magikos capture screenshot [smart|region|windows|fullscreen] [slurp|copy|save] [--editor=<name>]                                                                                                                         Take a screenshot
  magikos capture text                                                                                                                                                                                                     Extract text from a screenshot region with OCR
  magikos capture webcam resize <smaller|larger|reset|small|medium|large>                                                                                                                                                  Resize the active webcam recording overlay
```

Every command takes `--help` too, whether you ask a whole group (`magikos capture --help`) or a single command (`magikos capture screenshot --help`).

### Opening the menu from the terminal

The Magikos menu is scriptable as well, which is handy for your own keybindings. `magikos menu` opens it at the root, and you can jump straight to any point in the tree by naming it: `magikos menu summon style.theme` goes right to the theme picker, `magikos menu toggle system` opens the system menu and closes it again if it's already up, and `magikos menu close` puts it away.
