#!/bin/bash

set -euo pipefail

source "$(dirname "$0")/base-test.sh"

require_command jq

migration="$ROOT/migrations/1791865318.sh"
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT

mkdir -p "$test_dir/bin" "$test_dir/home"
home="$test_dir/home"

export MISE_LOG="$test_dir/mise.log"
export PKG_LOG="$test_dir/pkg.log"
export NPM_LOG="$test_dir/npm.log"

cat >"$test_dir/bin/mise" <<'SH'
#!/bin/bash
printf '%s\n' "$*" >>"$MISE_LOG"
SH

cat >"$test_dir/bin/magikos-cmd-missing" <<'SH'
#!/bin/bash
[[ $1 == "${MAGIKOS_TEST_MISSING_COMMAND:-__none__}" ]]
SH

cat >"$test_dir/bin/magikos-pkg-drop" <<'SH'
#!/bin/bash
printf 'drop:%s\n' "$*" >>"$PKG_LOG"
SH

cat >"$test_dir/bin/sudo" <<'SH'
#!/bin/bash
exec "$@"
SH

cat >"$test_dir/bin/systemctl" <<'SH'
#!/bin/bash
exit 0
SH

cat >"$test_dir/bin/npm" <<'SH'
#!/bin/bash
printf '%s\n' "$*" >>"$NPM_LOG"
SH

chmod +x "$test_dir"/bin/*

run_migration() {
  : >"$MISE_LOG"
  : >"$PKG_LOG"
  : >"$NPM_LOG"
  HOME="$home" PATH="$test_dir/bin:$PATH" bash -euo pipefail "$migration" >/dev/null
}

installer_shim() {
  printf '#!/bin/bash\nexport MISE_MINIMUM_RELEASE_AGE=0\nmise use -g --quiet "%s" || exit 1\nexec mise x "%s" -- "%s" "$@"\n' \
    "$1" "$1" "$2" >"$home/.local/bin/$2"
  chmod +x "$home/.local/bin/$2"
}

# Retired tools are unpinned and uninstalled, supported ones untouched.
run_migration
for tool in claude codex crush copilot pi "github:can1357/oh-my-pi" "npm:@xai-official/grok"; do
  grep -Fx "unuse -g $tool" "$MISE_LOG" >/dev/null || fail "retirement migration unpins $tool"
  grep -Fx "uninstall $tool" "$MISE_LOG" >/dev/null || fail "retirement migration uninstalls $tool"
done
for kept in antigravity-cli opencode gh node; do
  grep -F "$kept" "$MISE_LOG" >/dev/null && fail "retirement migration leaves $kept alone"
done
pass "retirement migration purges retired mise tools and keeps the supported ones"

# Installer-written stubs go, hand-written and supported ones stay.
mkdir -p "$home/.local/bin"
installer_shim pi pi
installer_shim "github:can1357/oh-my-pi" omp
installer_shim "npm:@xai-official/grok" grok
installer_shim crush crush
printf '#!/bin/bash\nexec /opt/pi "$@"\n' >"$home/.local/bin/handpi"
chmod +x "$home/.local/bin/handpi"
touch "$home/.local/bin/agy" "$home/.local/bin/opencode"
run_migration
for command in pi omp grok crush; do
  [[ ! -e $home/.local/bin/$command ]] || fail "retirement migration removes the $command stub"
done
[[ -f $home/.local/bin/handpi ]] || fail "retirement migration leaves a hand-written wrapper alone"
[[ -f $home/.local/bin/agy && -f $home/.local/bin/opencode ]] || fail "retirement migration keeps supported stubs"
pass "retirement migration removes installer stubs without touching anything else"

# Retired harness state goes, skill locations for the remaining agents stay.
mkdir -p "$home/.claude/skills" "$home/.codex" "$home/.cline" "$home/.openhands" \
  "$home/.pi/agent" "$home/.grok" "$home/.agents/skills" "$home/.gemini/config/skills"
touch "$home/.claude.json"
run_migration
for gone in .claude .codex .cline .openhands .pi .grok .claude.json; do
  [[ ! -e $home/$gone ]] || fail "retirement migration removes $gone"
done
[[ -d $home/.agents/skills && -d $home/.gemini/config/skills ]] ||
  fail "retirement migration keeps the skill directories of the remaining agents"
pass "retirement migration clears retired harness state and keeps skill locations"

# Stale usage records and scanner caches have no readers left.
mkdir -p "$home/.local/state/magikos/agents/usage" "$home/.cache/magikos/agent-usage"
run_migration
[[ ! -e $home/.local/state/magikos/agents && ! -e $home/.cache/magikos/agent-usage ]] ||
  fail "retirement migration drops orphaned usage data"
pass "retirement migration drops orphaned usage data"

# A default naming a retired agent remaps to an installed supported one.
mkdir -p "$home/.config/magikos/defaults"
printf '%s\n' crush >"$home/.config/magikos/defaults/agent"
export MAGIKOS_TEST_MISSING_COMMAND=agy
run_migration
[[ $(<"$home/.config/magikos/defaults/agent") == "opencode" ]] ||
  fail "retirement migration remaps a retired default to OpenCode"

printf '%s\n' copilot >"$home/.config/magikos/defaults/agent"
export MAGIKOS_TEST_MISSING_COMMAND=opencode
run_migration
[[ $(<"$home/.config/magikos/defaults/agent") == "agy" ]] ||
  fail "retirement migration falls back to Antigravity when OpenCode is missing"
unset MAGIKOS_TEST_MISSING_COMMAND

printf '%s\n' opencode >"$home/.config/magikos/defaults/agent"
run_migration
[[ $(<"$home/.config/magikos/defaults/agent") == "opencode" ]] ||
  fail "retirement migration leaves a supported default alone"
pass "retirement migration remaps retired defaults without touching supported ones"

# The retired bar widget leaves existing layouts, unparsable files excepted.
cat >"$home/.config/magikos/shell.json" <<'JSON'
{"bar": {"layout": {"left": ["magikos.clock"], "right": [{"id": "magikos.agents", "syncMode": "On"}, "magikos.agents", {"id": "magikos.tray"}]}}, "disabledPlugins": ["magikos.agents", "magikos.weather"]}
JSON
run_migration
[[ $(jq -c . "$home/.config/magikos/shell.json") == '{"bar":{"layout":{"left":["magikos.clock"],"right":[{"id":"magikos.tray"}]}},"disabledPlugins":["magikos.weather"]}' ]] ||
  fail "retirement migration strips the agents widget from shell.json" "$(cat "$home/.config/magikos/shell.json")"
pass "retirement migration strips the agents widget from shell.json"

printf '{ not json' >"$home/.config/magikos/shell.json"
run_migration
[[ $(cat "$home/.config/magikos/shell.json") == '{ not json' ]] ||
  fail "retirement migration leaves an unparsable shell.json untouched"
pass "retirement migration leaves an unparsable shell.json untouched"

# Retired packages are dropped with their models and data.
run_migration
for package in ollama openai-codex-desktop grok-bot lmstudio-bin t3code-bin; do
  grep -F "$package" "$PKG_LOG" >/dev/null || fail "retirement migration drops $package"
done
grep -F "uninstall -g cline @openhands/agent-canvas" "$NPM_LOG" >/dev/null ||
  fail "retirement migration removes retired global npm CLIs"
pass "retirement migration drops retired packages and npm CLIs"
