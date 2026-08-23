#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

test_tmp=$(mktemp -d)
trap 'rm -rf "$test_tmp"' EXIT

mock_bin="$test_tmp/bin"
test_home="$test_tmp/home"
mkdir -p "$mock_bin" "$test_home/.local/share/applications"

cat >"$test_home/.local/share/applications/chromium.desktop" <<'EOF'
[Desktop Entry]
Exec=chromium %U
EOF

cat >"$mock_bin/xdg-settings" <<'SH'
#!/bin/bash
[[ -z ${BROWSER:-} ]] || printf '%s\n' "$BROWSER" >"$MAGIKOS_TEST_XDG_SETTINGS_BROWSER"
[[ ${MAGIKOS_TEST_XDG_SETTINGS_EMPTY:-0} == "1" ]] || echo chromium.desktop
SH
cat >"$mock_bin/xdg-mime" <<'SH'
#!/bin/bash
if [[ $* == "query default x-scheme-handler/https" ]]; then
  echo chromium.desktop
fi
SH
cat >"$mock_bin/chromium" <<'SH'
#!/bin/bash
exit 0
SH
cat >"$mock_bin/systemd-run" <<'SH'
#!/bin/bash
printf '%s\n' "$*" >"$MAGIKOS_TEST_BROWSER_LAUNCH"
SH
chmod +x "$mock_bin"/*

launch_log="$test_tmp/launch"
xdg_settings_browser="$test_tmp/xdg-settings-browser"
HOME="$test_home" PATH="$mock_bin:$PATH" \
  MAGIKOS_TEST_BROWSER_LAUNCH="$launch_log" \
  bash "$ROOT/bin/magikos-launch-browser"

HOME="$test_home" PATH="$mock_bin:$PATH" \
  MAGIKOS_TEST_BROWSER_LAUNCH="$launch_log" \
  bash "$ROOT/bin/magikos-launch-browser" --private

HOME="$test_home" PATH="$mock_bin:$PATH" \
  MAGIKOS_TEST_BROWSER_LAUNCH="$launch_log" \
  bash "$ROOT/bin/magikos-launch-browser" "https://example.test/authorize"

grep -F 'https://example.test/authorize' "$launch_log" >/dev/null || fail "browser launcher passes through the URL"

rm -f "$xdg_settings_browser"

HOME="$test_home" PATH="$mock_bin:$PATH" \
  BROWSER=magikos-launch-browser MAGIKOS_TEST_XDG_SETTINGS_EMPTY=1 \
  MAGIKOS_TEST_BROWSER_LAUNCH="$launch_log" \
  MAGIKOS_TEST_XDG_SETTINGS_BROWSER="$xdg_settings_browser" \
  bash "$ROOT/bin/magikos-launch-browser" "https://example.test/fallback"

grep -F 'https://example.test/fallback' "$launch_log" >/dev/null ||
  fail "browser launcher falls back to the HTTPS handler when xdg-settings is empty"
[[ ! -e $xdg_settings_browser ]] ||
  fail "browser launcher unsets BROWSER before reading xdg-settings"

pass "browser launcher follows opened links to the default browser"
