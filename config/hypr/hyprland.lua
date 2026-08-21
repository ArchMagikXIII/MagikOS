-- Learn how to configure Hyprland: https://wiki.hypr.land/Configuring/Start/

-- Magikos's bootstrap keeps path setup out of this user config.
dofile((os.getenv("MAGIKOS_PATH") or "/usr/share/magikos") .. "/default/hypr/bootstrap.lua")

-- Disable all Magikos default bindings. Add your own in hypr/bindings.lua.
-- magikos_default_bindings = false
--
-- Or disable only bindings for Magikos's preinstalled apps/web apps while
-- keeping core window-manager bindings:
-- magikos_preinstalled_bindings = false

-- Load Magikos defaults.
require("default.hypr.magikos")

-- Put your personal overrides in these files. They're loaded after Magikos's
-- defaults so package updates can improve the defaults without rewriting your
-- ~/.config/hypr files.
require("hypr.monitors")
require("hypr.input")
require("hypr.bindings")
require("hypr.looknfeel")
require("hypr.autostart")

-- Toggle config flags dynamically.
require("default.hypr.toggles")

-- Add any other personal Hyprland configuration below.
-- o.window("qemu", { workspace = "5" })
