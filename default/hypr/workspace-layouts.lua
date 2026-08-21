-- Restore workspace layouts saved by magikos-hyprland-workspace-layout-toggle.

local paths = require("default.hypr.paths")
local require_all = require("default.hypr.require_all")

local layouts_dir = paths.state_home .. "/magikos/workspace-layouts"

require_all.files(layouts_dir, "magikos.workspace-layouts", { reload = true })
