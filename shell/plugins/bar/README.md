# Magikos bar

This is the Quickshell implementation of the Magikos status bar. It is
shipped as a first-party plugin of [`magikos-shell`](../../README.md), the
long-running shell host. The bar is mounted at startup and lives inside
the shell for its whole session.

- `manifest.json` declares the plugin (`id: magikos.bar`, `kind: bar`) and points at `Bar.qml` as the entry point.
- `Bar.qml` is Magikos-owned bar engine code, loaded by the magikos-shell host. Users should not edit it directly.
- `widgets/` holds simple first-party bar widgets with sibling manifests.
- Feature plugins such as `../panels/audio/`, `../panels/network/`, `../panels/power/`, and `../agents/` provide richer popup bar plugins.
- The bar receives its config from the host shell as a `barConfig` property; the host loads it from `~/.config/magikos/shell.json` (or `config/magikos/shell.json` when the user has no file).
- `magikos bar position` updates only the user shell.json file.

## Customizing

The bar config lives under the `bar:` key of [`~/.config/magikos/shell.json`](../../README.md#shelljson-shape). Out of the box the shell uses [`config/magikos/shell.json`](../../../config/magikos/shell.json). Once you customize anything via the bar gestures, `magikos bar ...`, or by editing shell.json directly, your file is canonical — there is no deep-merge.

The bar is configured directly on the bar itself: drag empty bar space (or click-and-hold) to move the bar to another screen edge, double-left-click empty center-bar space to toggle transparency, and drag widgets to reorder them. The `magikos bar position`, `magikos bar transparent`, `magikos bar move`, and `magikos bar set` commands do the same from scripts. Enable or disable widgets with `magikos plugin enable` and `magikos plugin disable` (widget ids come from `magikos plugin list`).

Example `shell.json` (bar subtree only shown):

```json
{
  "version": 1,
  "bar": {
    "position": "top",
    "transparent": false,
    "centerAnchor": "magikos.clock",
    "layout": {
      "left": [
        { "id": "magikos.menu" },
        { "id": "magikos.spacer", "size": 12 },
        { "id": "magikos.workspaces" }
      ],
      "center": [
        { "id": "magikos.media" },
        { "id": "magikos.clock", "format": "HH:mm" }
      ],
      "right": [
        { "id": "magikos.audio" },
        { "id": "magikos.power" }
      ]
    }
  }
}
```

`centerAnchor` pins one center module to the exact horizontal/vertical center and flanks others around it. Set to an empty string to disable anchoring (the center list is centered as a group).

## Module catalogue

### First-party interactive widgets

| Name | What it does | Interactions |
|---|---|---|
| `magikos.menu` | Magikos menu launcher | left = menu · right = terminal |
| `magikos.workspaces` | Hyprland workspace switcher | left = focus workspace |
| `magikos.clock` | Date/time label + popup with a month grid, ISO week numbers, and month stepping | left = popup · right = cycle label format · middle = timezone selector |
| `magikos.media` | MPRIS now-playing — scrolling track + artist, cover-art popup | left = play/pause · middle = next · scroll = prev/next · right = popup |
| `magikos.indicators` | Manual state indicators | left = indicator action |
| `magikos.system-update` | Available update indicator | left = update |
| `magikos.tray` | System tray | hover = reveal drawer · right on chevron = manage |
| `magikos.weather` | Weather icon + popup with forecast | left = popup · right = full notification |
| `magikos.microphone` | Mic icon + scroll volume | left = mute toggle · middle = audio panel · scroll = source volume |

| `magikos.audio` | Volume icon + popup with master slider, output-device picker, per-app mixer | left = popup · right = mute · middle = popup · scroll = volume |
| `magikos.network` | Wi-Fi/Ethernet icon + popup with Wi-Fi scan, signal, connect, DNS provider selection | left = popup |
| `magikos.tailscale` | Tailscale status, connection switcher, machine browser, and copy actions | left = popup · right = toggle · middle = refresh |
| `magikos.agents` | AI coding agent limits with pace, today, last week, and all-time model breakdown | left = panel · right = launch agent · middle = next subscription |
| `magikos.power` | Battery/AC icon + popup with battery stats, power profiles, and system info | left = popup · right = toggle percentage |
| `magikos.bluetooth` | Bluetooth icon + popup with device list, connect/disconnect, battery | left = popup · right = toggle radio |
| `magikos.monitor` | Brightness and laptop display controls | left = popup |

The `magikos.indicators` widget loads individual bar indicators from `indicators/`. Omit `items` (or set it to an empty array) to show all indicators in the default order, or set `items` to a subset such as `["Dnd", "Reminder", "NightLight"]`. Set `alwaysShow` to `true` to keep inactive indicators visible instead of revealing them only on hover. Multiple `magikos.indicators` instances are allowed, so different sections can show different subsets.

### Default workspace icons

`magikos.workspaces` shows a distinct Nerd Font glyph per index (1–10) and falls back to the number itself beyond that. Workstations 1–5 carry the app icons from the author's daily-driver layout; 6–10 are the decorative set. The glyph mapping lives in `widgets/Workspaces.qml`; glyphs on supplementary Unicode planes (`U+F0xxx`, e.g. Discord, creation, lightning, atom, robot, firework) are written as UTF-16 surrogate-pair escapes so they survive any font stack.

| Index | Icon | Codepoint |
|---|---|---|
| 1 | Discord | nf-md-discord `U+F066F` |
| 2 | Terminal | nf-fa-terminal `U+F120` |
| 3 | Firefox | nf-fa-firefox `U+F269` |
| 4 | Sparkles (agent) | nf-md-creation `U+F0674` |
| 5 | Steam | nf-fa-steam `U+F1B6` |
| 6 | Gamepad | nf-md-gamepad `U+F11B` |
| 7 | Lightning | nf-md-lightning_bolt `U+F140B` |
| 8 | Atom | nf-md-atom `U+F0768` |
| 9 | Robot | nf-md-robot_happy `U+F1719` |
| 10 | Firework | nf-md-firework `U+F0E30` |

## Orientation

All widgets work in `top`, `bottom`, `left`, and `right` positions. Popups anchor on the side opposite the bar edge, sliding into the workspace. Vertical bars use 28px width; widgets that show text fall back to compact icon-only forms (e.g. `media` hides its scrolling label).

## Custom user modules

The schema accepts arbitrary module ids that you provide. Set `type` to `command` for shell-driven output or `qml` for a custom QML widget. Both still go under `bar.layout.<section>` in `shell.json`.

Command module:

```json
{
  "version": 1,
  "bar": {
    "layout": {
      "right": [
        { "id": "magikos.tray" },
        { "id": "vpn", "type": "command", "exec": "~/.config/magikos/bar/scripts/vpn-status", "interval": 5, "tooltip": "VPN", "onClick": "nm-connection-editor" },
        { "id": "magikos.audio" }
      ]
    }
  }
}
```

The command may print plain text or Waybar-style JSON, for example:

```json
{"text":"󰌆","tooltip":"Work VPN","class":"active"}
```

QML module:

```json
{
  "version": 1,
  "bar": {
    "layout": {
      "right": [
        { "id": "gpu", "type": "qml" },
        { "id": "magikos.audio" }
      ]
    }
  }
}
```

Then create `~/.config/magikos/bar/modules/gpu.qml`. If you want to store it elsewhere, add a `source` path.

Custom QML modules should be an `Item` with `implicitWidth` and `implicitHeight`. They may optionally define these properties, which the bar fills after loading:

```qml
import QtQuick

Item {
  property var bar
  property string moduleName
  property var settings

  implicitWidth: 28
  implicitHeight: bar ? bar.barSize : 26

  Text {
    anchors.centerIn: parent
    text: "GPU"
    color: bar ? bar.foreground : "white"
    font.family: bar ? bar.fontFamily : "monospace"
    font.pixelSize: 12
  }

  MouseArea {
    anchors.fill: parent
    onClicked: if (bar) bar.run("magikos-launch-or-focus-tui btop")
  }
}
```

## Bar properties available to widgets

Widgets receive `bar` (the shell root), `moduleName` (string), and `settings` (object) injected at load time. The bar exposes:

- `bar.foreground`, `bar.background`, `bar.urgent` — theme colors (live-updated)
- `bar.fontFamily` — current monospace family
- `bar.position` — `"top" | "bottom" | "left" | "right"`
- `bar.vertical` — boolean shortcut
- `bar.barSize` — 26 horizontal / 28 vertical
- `bar.run(command)` — fire-and-forget bash exec (quote arguments with `Util.shellQuote` from `qs.Commons`)
- `bar.showTooltip(target, text)` / `bar.hideTooltip(target)` — shared tooltip popup
- `bar.requestPopout(owner)` / `bar.releasePopout(owner)` — one-popup-at-a-time coordinator

First-party bar widgets are manifest-backed just like third-party widgets.
Simple widgets carry sibling manifests such as `widgets/Workspaces.manifest.json`;
richer popup plugins live in feature directories such as `../panels/audio/`,
`../panels/network/`, and `../agents/`; and feature plugins such as
`magikos.menu` and `magikos.media` declare their bar-widget entry points in their own
`manifest.json`. Bar layout ids are namespaced, e.g. `magikos.audio`,
`magikos.network`, and `magikos.clock`.

Third-party widgets ship as separate plugins under
`~/.config/magikos/plugins/<plugin-id>/` with their own `manifest.json`
declaring `kinds: ["bar-widget"]` and a `barWidget` entry point. See
[../../README.md](../../README.md) for the manifest schema. Rescan, enable,
and place third-party plugins with `magikos-shell shell rescanPlugins`,
`magikos plugin enable`, and `magikos bar move`.
