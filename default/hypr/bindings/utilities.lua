o.bind("SUPER + SPACE", "Magikos menu", "magikos-menu toggle")
o.bind("SUPER + ALT + SPACE", "Apps menu", "magikos-menu toggle apps")
o.bind("SUPER + CTRL + E", "Emojis", "magikos-shell shell toggle magikos.emojis")
o.bind("SUPER + CTRL + C", "Capture menu", "magikos-menu toggle capture")
o.bind("SUPER + CTRL + O", "Toggle menu", "magikos-menu toggle toggle")
o.bind("SUPER + CTRL + H", "Hardware menu", "magikos-menu toggle hardware")
o.bind("SUPER + SHIFT + code:201", "Magikos menu", "magikos-menu toggle root")
o.bind("SUPER + ESCAPE", "System menu", "magikos-menu toggle system")
o.bind("XF86PowerOff", "Power menu", "magikos-menu toggle system", { locked = true })
o.bind("SUPER + K", "Keybindings", "magikos-menu-keybindings")
o.bind("SUPER + ALT + K", "Tmux keybindings", "magikos-menu-tmux-keybindings")
o.bind("SUPER + CTRL + K", "Herdr keybindings", "magikos-menu-herdr-keybindings")
o.bind("SUPER + CTRL + Q", "Calculator", "omacalc")
o.bind("XF86Calculator", "Calculator", "omacalc")

o.bind_toggle("SUPER + SHIFT + SPACE", "Toggle top bar", "bar")
o.bind("SUPER + CTRL + SPACE", "Background switcher", "magikos-menu toggle background")
o.bind("SUPER + SHIFT + CTRL + SPACE", "Theme menu", "magikos-menu toggle theme")
o.bind("SUPER + BACKSPACE", "Toggle window transparency", "magikos-hyprland-window-transparency-toggle")
o.bind("SUPER + SHIFT + BACKSPACE", "Toggle window gaps", "magikos-hyprland-window-gaps-toggle")
o.bind("SUPER + CTRL + BACKSPACE", "Toggle single-window square aspect", "magikos-hyprland-window-single-square-aspect-toggle")

-- xkbcommon names the comma keysym "comma"; the upper-case "COMMA" does not match.
o.bind("SUPER + comma", "Dismiss last notification", "magikos-shell notifications dismissOne")
o.bind("SUPER + SHIFT + comma", "Dismiss all notifications", "magikos-shell notifications dismissAll")
o.bind_toggle("SUPER + CTRL + comma", "Toggle silencing notifications", "notification-silencing")
o.bind("SUPER + ALT + comma", "Invoke last notification", "magikos-shell notifications invokeLast")
o.bind("SUPER + SHIFT + ALT + comma", "Open notification history", "magikos-shell notifications showHistory")

o.bind_toggle("SUPER + CTRL + I", "Toggle locking on idle", "idle")
o.bind_toggle("SUPER + CTRL + N", "Toggle nightlight", "nightlight")
o.bind("SUPER + CTRL + Delete", "Toggle laptop display", "magikos-hyprland-monitor-internal toggle")
o.bind("SUPER + CTRL + ALT + Delete", "Toggle laptop display mirroring", "magikos-hyprland-monitor-internal-mirror toggle")
o.bind("switch:on:Lid Switch", nil, "magikos-system-lid-close", { locked = true })
o.bind("switch:off:Lid Switch", nil, "magikos-hyprland-monitor-clamshell", { locked = true })

o.bind("PRINT", "Screenshot", "magikos-capture-screenshot")
o.bind("ALT + PRINT", "Screenrecording", "magikos-capture-screenrecording --stop-recording || magikos-menu toggle trigger.capture.screenrecord")
o.bind("SUPER + ALT + code:34", "Make webcam overlay smaller", "magikos-capture-webcam-resize smaller")
o.bind("SUPER + ALT + code:35", "Make webcam overlay larger", "magikos-capture-webcam-resize larger")
o.bind("SUPER + PRINT", "Color picker", "pkill hyprpicker || hyprpicker -a")
o.bind("SUPER + CTRL + PRINT", "Extract text (OCR) from screenshot", "magikos-capture-text")

-- Keyboard control for the slurp region picker (see magikos-capture-region).
-- The binds live exactly as long as a selection layer is on screen (slurp
-- opens one per monitor), so they cannot leak or get stuck.
-- Unbinding by key would take a same-key binding out of the user's own config
-- with it, so each handle is kept and removed individually.
local selection_layers = 0
local selection_binds = {}

hl.on("layer.opened", function(layer)
  if layer.namespace == "selection" then
    selection_layers = selection_layers + 1
    if selection_layers == 1 then
      selection_binds = {
        hl.bind("RETURN", hl.dsp.exec_cmd("magikos-capture-region --take-window"), { description = "Capture highlighted window" }),
        hl.bind("CTRL + RETURN", hl.dsp.exec_cmd("magikos-capture-region --take-fullscreen"), { description = "Capture entire screen" }),
        hl.bind("TAB", hl.dsp.exec_cmd("magikos-capture-region --select-window next"), { description = "Select next window to capture" }),
        hl.bind("CTRL + TAB", hl.dsp.exec_cmd("magikos-capture-region --select-window prev"), { description = "Select previous window to capture" }),
      }
      for _, direction in ipairs({ "left", "right", "up", "down" }) do
        table.insert(
          selection_binds,
          hl.bind(direction:upper(), hl.dsp.exec_cmd("magikos-capture-region --select-window " .. direction), { description = "Select window to capture" })
        )
      end
    end
  end
end)

hl.on("layer.closed", function(layer)
  if layer.namespace == "selection" and selection_layers > 0 then
    selection_layers = selection_layers - 1
    if selection_layers == 0 then
      for _, keybind in ipairs(selection_binds) do
        keybind:unbind()
      end
      selection_binds = {}
    end
  end
end)

o.bind("SUPER + CTRL + S", "Share", "magikos-menu toggle share")

o.bind("SUPER + CTRL + PERIOD", "Transcode", "magikos-transcode")

o.bind("SUPER + CTRL + R", "Set reminder", "magikos-menu toggle reminder-set")
o.bind("SUPER + CTRL + ALT + R", "Show reminders", "magikos-reminder show")
o.bind("SUPER + SHIFT + CTRL + R", "Clear reminders", "magikos-reminder clear")

o.bind("SUPER + CTRL + ALT + T", "Show time", "magikos-notification-time")
o.bind("SUPER + CTRL + ALT + B", "Show battery remaining", "magikos-notification-battery")
o.bind("SUPER + CTRL + ALT + W", "Toggle weather", "magikos-notification-weather")

o.bind("SUPER + SHIFT + CTRL + A", "Agent", "magikos-agent --pick")
o.bind("SUPER + CTRL + A", "Audio", "magikos-shell shell toggle magikos.audio")
o.bind("SUPER + CTRL + B", "Bluetooth", "magikos-shell shell toggle magikos.bluetooth")
o.bind("SUPER + CTRL + D", "Display", "magikos-shell shell toggle magikos.monitor")
o.bind("SUPER + CTRL + ALT + D", "Calendar", "magikos-shell shell toggle magikos.clock")
o.bind("SUPER + CTRL + W", "Network", "magikos-shell shell toggle magikos.network")
o.bind("SUPER + CTRL + P", "Power", "magikos-shell shell toggle magikos.power")
o.bind("SUPER + CTRL + T", "Activity", { tui = "btop" })

-- The letters above name a panel; the numbers count them. 1 is the leftmost
-- panel in the bar's right section, and a widget with no panel of its own (the
-- tray) is not counted, so the number matches the icon a user would point at.
-- A bar with fewer panels than this leaves the tail of the range doing nothing.
for panel = 1, 9 do
  o.bind(
    "SUPER + CTRL + code:" .. tostring(panel + 9),
    "Bar panel " .. panel,
    "magikos-shell -q shell togglePanelAt right " .. panel
  )
end

o.bind("SUPER + CTRL + Z", "Zoom in", function()
  local zoom = hl.get_config("cursor.zoom_factor") or 1
  hl.config({ cursor = { zoom_factor = zoom + 1 } })
end)

o.bind("SUPER + CTRL + ALT + Z", "Reset zoom", function()
  hl.config({ cursor = { zoom_factor = 1 } })
end)

o.bind("SUPER + CTRL + L", "Lock system", "magikos-system-lock")
