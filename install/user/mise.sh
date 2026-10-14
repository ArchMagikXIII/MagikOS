# Every tool here installs on first run through mise, which is not in every
# base set (see mise-work.sh). Bracketing the whole leaf keeps one missing
# toolchain from aborting the leaves that follow it under run_logged's errexit,
# and reads correctly whether the leaf is sourced or run directly.
if command -v mise >/dev/null 2>&1; then
  magikos-mise-install antigravity-cli agy
  magikos-mise-install gh
  magikos-mise-install opencode
  magikos-mise-install npm:playwright playwright
  magikos-mise-install npm:@kitlangton/ghui ghui
  magikos-mise-install aqua:modem-dev/hunk hunk
  magikos-mise-install github:basecamp/hey-cli hey
else
  echo "mise not installed; skipping mise-backed tool wrappers"
fi