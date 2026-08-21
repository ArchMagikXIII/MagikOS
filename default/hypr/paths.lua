-- Shared path constants for Magikos's Hyprland Lua modules.
-- Lua files loaded with require() have separate local scopes, so modules that
-- need these paths import this table instead of repeating os.getenv() lookups.

local home = os.getenv("HOME")

return {
  home = home,
  config_home = os.getenv("XDG_CONFIG_HOME") or (home .. "/.config"),
  state_home = os.getenv("XDG_STATE_HOME") or (home .. "/.local/state"),
  magikos_path = os.getenv("MAGIKOS_PATH") or "/usr/share/magikos",
}
