#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

test_tmp=$(mktemp -d)
trap 'rm -rf "$test_tmp"' EXIT

mock_bin="$test_tmp/bin"
test_home="$test_tmp/home"
agent_file="$test_home/.config/magikos/defaults/agent"
notification_history="$test_tmp/notification-history"
agent_open_log="$test_tmp/agent-open"
launch_log="$test_tmp/launch"
inline_log="$test_tmp/inline"
mise_log="$test_tmp/mise"
mise_history="$test_tmp/mise-history"
stub_log="$test_tmp/stubs"
terminal_log="$test_tmp/terminal"
menu_log="$test_tmp/menu"
mkdir -p "$mock_bin" "$test_home"

cat >"$mock_bin/magikos-notification-send" <<'SH'
#!/bin/bash
printf '%s\0' "$@" >>"$MAGIKOS_TEST_NOTIFICATION_HISTORY"
SH

cat >"$mock_bin/magikos-cmd-missing" <<'SH'
#!/bin/bash
[[ $1 == ${MAGIKOS_TEST_MISSING_COMMAND:-} ]]
SH

cat >"$mock_bin/magikos-launch-tui" <<'SH'
#!/bin/bash
printf '%s\0' "$@" >"$MAGIKOS_TEST_AGENT_LAUNCH_LOG"
SH

cat >"$mock_bin/magikos-launch-floating-terminal-with-presentation" <<'SH'
#!/bin/bash
printf '%s\0' "$@" >"$MAGIKOS_TEST_AGENT_TERMINAL_LOG"
SH

cat >"$mock_bin/opencode" <<'SH'
#!/bin/bash
printf '%s\0' opencode "$@" >"$MAGIKOS_TEST_AGENT_INLINE_LOG"
SH

cat >"$mock_bin/magikos-mise-install" <<'SH'
#!/bin/bash
printf '%s\n' "$*" >>"$MAGIKOS_TEST_STUB_LOG"
SH

cat >"$mock_bin/mise" <<'SH'
#!/bin/bash
printf '%s\0' "$@" >"$MAGIKOS_TEST_MISE_LOG"
printf '%s\n' "$*" >>"$MAGIKOS_TEST_MISE_HISTORY"

if [[ $1 == "where" ]]; then
  [[ ${MAGIKOS_TEST_AGENT_INSTALLED:-false} == "true" ]]
  exit
fi

[[ ${MAGIKOS_TEST_MISE_FAIL:-false} != "true" ]]
SH

cat >"$mock_bin/magikos-menu" <<'SH'
#!/bin/bash
printf '%s\0' "$@" >"$MAGIKOS_TEST_AGENT_MENU_LOG"
SH

cat >"$mock_bin/magikos-test-noop" <<'SH'
#!/bin/bash
exit 0
SH

for command in gum magikos-webapp-remove-all magikos-tui-remove-all magikos-pkg-drop; do
  ln -s magikos-test-noop "$mock_bin/$command"
done

chmod +x "$mock_bin"/*

export HOME="$test_home"
export PATH="$mock_bin:$ROOT/bin:$PATH"
export MAGIKOS_TEST_NOTIFICATION_HISTORY="$notification_history"
export MAGIKOS_TEST_AGENT_OPEN_LOG="$agent_open_log"
export MAGIKOS_TEST_AGENT_LAUNCH_LOG="$launch_log"
export MAGIKOS_TEST_AGENT_INLINE_LOG="$inline_log"
export MAGIKOS_TEST_MISE_LOG="$mise_log"
export MAGIKOS_TEST_MISE_HISTORY="$mise_history"
export MAGIKOS_TEST_STUB_LOG="$stub_log"
export MAGIKOS_TEST_AGENT_TERMINAL_LOG="$terminal_log"
export MAGIKOS_TEST_AGENT_MENU_LOG="$menu_log"
export MAGIKOS_PATH="$ROOT"

agy_package="antigravity-cli"

# Retired packages below only cover pre-retirement migrations, which still
# install their shims on the way through history; the retirement migration
# purges them afterwards.
grok_package="npm:@xai-official/grok"
omp_package="github:can1357/oh-my-pi"
crush_package="crush"

assert_lazy_stub() {
  local package=$1
  local command=$2

  : >"$mise_history"
  "$ROOT/bin/magikos-mise-install" "$package" "$command"
  "$test_home/.local/bin/$command" --version
  mapfile -t mise_calls <"$mise_history"

  [[ ${mise_calls[0]} == "use -g --quiet $package" && ${mise_calls[1]} == "x $package -- $command --version" ]] ||
    fail "$command lazy stub preserves its mise package"
}

assert_lazy_stub "$agy_package" agy
pass "custom agent lazy stubs preserve their mise packages"

source "$ROOT/install/user/mise.sh"
grep -Fx "$agy_package agy" "$stub_log" >/dev/null || fail "user setup creates the Antigravity lazy stub"
grep -Fx "opencode" "$stub_log" >/dev/null || fail "user setup creates the OpenCode lazy stub"
for retired in "claude" "codex" "crush" "copilot" "pi" "github:can1357/oh-my-pi omp" "npm:@xai-official/grok grok"; do
  grep -Fx "$retired" "$stub_log" >/dev/null && fail "user setup no longer creates the retired $retired stub"
done
pass "user setup creates only the supported agent lazy stubs"

: >"$stub_log"
source "$ROOT/migrations/1785617047.sh" >/dev/null
grep -Fx "$omp_package omp" "$stub_log" >/dev/null || fail "Oh My Pi migration creates a working lazy stub"

: >"$stub_log"
source "$ROOT/migrations/1785846769.sh" >/dev/null
grep -Fx "$omp_package omp" "$stub_log" >/dev/null || fail "agent migration repairs the Oh My Pi lazy stub"
grep -Fx "$grok_package grok" "$stub_log" >/dev/null || fail "agent migration creates the Grok lazy stub"
grep -Fx "$crush_package" "$stub_log" >/dev/null || fail "agent migration creates the Crush lazy stub"

: >"$stub_log"
mkdir -p "$(dirname "$agent_file")"
printf '%s\n' gemini >"$agent_file"
"$ROOT/bin/magikos-mise-install" gemini
export MAGIKOS_TEST_MISSING_COMMAND=agy
source "$ROOT/migrations/1786719479.sh" >/dev/null
unset MAGIKOS_TEST_MISSING_COMMAND
grep -Fx "$agy_package agy" "$stub_log" >/dev/null || fail "Antigravity migration creates its lazy stub"
[[ $(<"$agent_file") == "agy" ]] || fail "Antigravity migration replaces a Gemini default"

: >"$stub_log"
printf '  %s  \n' gemini >"$agent_file"
export MAGIKOS_TEST_MISSING_COMMAND=agy
source "$ROOT/migrations/1786719479.sh" >/dev/null
unset MAGIKOS_TEST_MISSING_COMMAND
[[ $(<"$agent_file") == "agy" ]] ||
  fail "Antigravity migration replaces a padded Gemini default the launcher would still read"
pass "Antigravity migration reads the default the way the launcher does"

for obsolete_form in 'mise use -g "gemini"' 'mise use -g --quiet "gemini"'; do
  printf '#!/bin/bash\n%s || exit 1\n' "$obsolete_form" >"$test_home/.local/bin/gemini"
  chmod +x "$test_home/.local/bin/gemini"
  source "$ROOT/migrations/1786719479.sh" >/dev/null
  [[ ! -e $test_home/.local/bin/gemini ]] ||
    fail "Antigravity migration removes a wrapper built on [$obsolete_form]"
done

printf '#!/bin/bash\nexec /opt/gemini "$@"\n' >"$test_home/.local/bin/gemini"
chmod +x "$test_home/.local/bin/gemini"
source "$ROOT/migrations/1786719479.sh" >/dev/null
[[ -e $test_home/.local/bin/gemini ]] || fail "Antigravity migration leaves a hand-written gemini alone"

printf '#!/bin/bash\n# replaced: mise use -g --quiet "gemini"\nexec /opt/gemini "$@"\n' >"$test_home/.local/bin/gemini"
chmod +x "$test_home/.local/bin/gemini"
source "$ROOT/migrations/1786719479.sh" >/dev/null
[[ -e $test_home/.local/bin/gemini ]] ||
  fail "Antigravity migration leaves a wrapper that only mentions the installer line"
rm -f "$test_home/.local/bin/gemini"
pass "Antigravity migration only removes the Gemini wrapper Magikos wrote"

[[ -L "$test_home/.gemini/config/skills/magikos" && $(readlink "$test_home/.gemini/config/skills/magikos") == "$ROOT/default/agents/skills/magikos" ]] ||
   fail "Antigravity migration provisions the magikos skill"
[[ -L "$test_home/.gemini/config/skills/diagnose-crash" && $(readlink "$test_home/.gemini/config/skills/diagnose-crash") == "$ROOT/default/agents/skills/diagnose-crash" ]] ||
   fail "Antigravity migration provisions the diagnose-crash skill"
pass "Antigravity migration provisions Antigravity skills"


: >"$stub_log"
mkdir -p "$test_home/.local/state/magikos"
touch "$test_home/.local/state/magikos/preinstalls-removed"
export MAGIKOS_TEST_MISSING_COMMAND=agy
source "$ROOT/migrations/1786719479.sh" >/dev/null
[[ ! -s $stub_log ]] || fail "Antigravity migration preserves removed preinstalls"
pass "Antigravity migration respects removed preinstalls"

: >"$stub_log"
printf '%s\n' gemini >"$agent_file"
source "$ROOT/migrations/1786719479.sh" >/dev/null
unset MAGIKOS_TEST_MISSING_COMMAND
grep -Fx "$agy_package agy" "$stub_log" >/dev/null || fail "Antigravity migration installs the agent a Gemini default now names"
[[ $(<"$agent_file") == "agy" ]] || fail "Antigravity migration replaces a Gemini default after opt-out"
pass "Antigravity migration never leaves the default naming a missing agent"

: >"$stub_log"
rm "$test_home/.local/state/magikos/preinstalls-removed"
source "$ROOT/migrations/1786719479.sh" >/dev/null
[[ ! -s $stub_log ]] || fail "Antigravity migration reinstalls an existing Antigravity command"
pass "Antigravity migration preserves an existing Antigravity install"

mkdir -p "$test_home/.local/state/magikos"
touch "$test_home/.local/state/magikos/preinstalls-removed"
"$ROOT/bin/magikos-mise-install" oh-my-pi omp
: >"$stub_log"
source "$ROOT/migrations/1785617047.sh" >/dev/null
source "$ROOT/migrations/1785846769.sh" >/dev/null
[[ ! -s $stub_log ]] || fail "agent migrations respect the preinstall opt-out"
[[ ! -e $test_home/.local/bin/omp ]] || fail "agent migration removes the obsolete Oh My Pi wrapper after opt-out"

# The matcher has to catch a bare oh-my-pi wrapper from either generation of the
# installer, and leave a wrapper built on the fully qualified package alone.
for obsolete_form in 'mise use -g "oh-my-pi"' 'mise use -g --quiet "oh-my-pi"'; do
  printf '#!/bin/bash\n%s || exit 1\n' "$obsolete_form" >"$test_home/.local/bin/omp"
  chmod +x "$test_home/.local/bin/omp"
  source "$ROOT/migrations/1785846769.sh" >/dev/null
  [[ ! -e $test_home/.local/bin/omp ]] ||
    fail "agent migration removes a wrapper built on [$obsolete_form]"
done

printf '#!/bin/bash\nmise use -g --quiet "%s" || exit 1\n' "$omp_package" >"$test_home/.local/bin/omp"
chmod +x "$test_home/.local/bin/omp"
source "$ROOT/migrations/1785846769.sh" >/dev/null
[[ -e $test_home/.local/bin/omp ]] ||
  fail "agent migration keeps a wrapper built on $omp_package"
rm -f "$test_home/.local/bin/omp"

rm "$test_home/.local/state/magikos/preinstalls-removed"
rm -f "$agent_file"
pass "agent migrations install working wrappers without overriding the preinstall opt-out"

touch "$test_home/.local/bin/agy" "$test_home/.local/bin/opencode"
magikos-remove-preinstalls >/dev/null
for command in agy opencode; do
  [[ ! -e $test_home/.local/bin/$command ]] || fail "Remove Preinstalls deletes the $command lazy stub"
done
pass "Remove Preinstalls deletes every supported agent lazy stub"

[[ -z $(magikos-default-agent) ]] || fail "default agent is unset until one is chosen"
pass "default agent is unset until one is chosen"

: >"$launch_log"
if magikos-agent >"$test_tmp/no-agent-output" 2>&1; then
  fail "agent launcher refuses to launch without a default"
fi
grep -Fq "Choose default agent with" "$test_tmp/no-agent-output" ||
  fail "agent launcher explains that no default is set"
[[ ! -s $launch_log ]] || fail "agent launcher starts nothing without a default"
pass "agent launcher refuses to launch without a default"

# The keybinding uses --pick, where an error on stderr nobody sees would make
# the keypress look broken. It offers the choice instead.
: >"$launch_log"
: >"$menu_log"
magikos-agent --pick
mapfile -d '' -t menu_args <"$menu_log"
[[ ${menu_args[*]} == "summon setup.default.agent" ]] ||
  fail "--pick opens the agent defaults menu when none is set"
[[ ! -s $launch_log ]] || fail "--pick starts nothing when no agent is set"
pass "--pick opens the agent defaults menu when none is set"

source "$ROOT/default/bash/aliases"
[[ $(alias a) == "alias a='magikos-agent --inline'" ]] ||
  fail "terminal alias launches the default agent inline"
pass "terminal alias launches the default agent inline"

cat >"$mock_bin/magikos-agent" <<'SH'
#!/bin/bash
printf '%s\0' magikos-agent "$@" >"$MAGIKOS_TEST_AGENT_OPEN_LOG"
SH
chmod +x "$mock_bin/magikos-agent"
hash -r

declare -A expected_agents=(
  [opencode]="opencode"
  [open-code]="opencode"
  [agy]="agy"
  [antigravity]="agy"
  [antigravity-cli]="agy"
  [gemini]="agy"
  [gemini-cli]="agy"
)

declare -A expected_packages=(
  [opencode]="opencode"
  [agy]="$agy_package"
)

for selection in "${!expected_agents[@]}"; do
  expected=${expected_agents[$selection]}
  : >"$agent_open_log"
  MAGIKOS_TEST_AGENT_INSTALLED=true magikos-default-agent "$selection"
  [[ $(magikos-default-agent) == $expected ]] || fail "default agent canonicalizes $selection"

  mapfile -d '' -t mise_args <"$mise_log"
  [[ ${mise_args[0]} == "use" && ${mise_args[1]} == "-g" && ${mise_args[2]} == ${expected_packages[$expected]} ]] ||
    fail "default agent installs $selection globally through mise"

  mapfile -d '' -t agent_open_args <"$agent_open_log"
  [[ ${#agent_open_args[@]} == 1 && ${agent_open_args[0]} == "magikos-agent" ]] ||
    fail "default agent opens $selection after selecting it"
done
pass "default agent selects and opens every supported provider and alias"
[[ -f $agent_file && ! -e $test_home/.local/state/magikos/defaults/agent ]] ||
  fail "default agent stores its selection in Magikos user config"
pass "default agent stores its selection in Magikos user config"

MAGIKOS_TEST_AGENT_INSTALLED=true magikos-default-agent opencode
: >"$notification_history"
: >"$agent_open_log"
: >"$terminal_log"
magikos-default-agent agy
mapfile -d '' -t terminal_args <"$terminal_log"
[[ ${terminal_args[0]} == "magikos-default-agent" && ${terminal_args[1]} == "--install" && ${terminal_args[2]} == "agy" ]] ||
  fail "missing agent installation opens in a terminal"
[[ ! -s $notification_history ]] || fail "missing agent installation skips notifications"
[[ ! -s $agent_open_log ]] || fail "missing agent installation waits to open the agent"
[[ $(magikos-default-agent) == "opencode" ]] || fail "missing agent installation waits to change the selection"

magikos-default-agent --install agy >"$test_tmp/install-output"
mapfile -d '' -t mise_args <"$mise_log"
[[ ${mise_args[0]} == "use" && ${mise_args[1]} == "-g" && ${mise_args[2]} == "antigravity-cli" ]] ||
  fail "visible agent installation activates the provider globally through mise"
[[ $(magikos-default-agent) == "agy" ]] || fail "visible agent installation changes the selection after mise succeeds"
[[ ! -s $notification_history ]] || fail "visible agent installation leaves progress to the terminal"
[[ $(<"$test_tmp/install-output") == $'\033[2J\033[3J\033[H' ]] ||
  fail "visible agent installation clears its terminal before opening the agent"
mapfile -d '' -t agent_open_args <"$agent_open_log"
[[ ${#agent_open_args[@]} == 2 && ${agent_open_args[0]} == "magikos-agent" && ${agent_open_args[1]} == "--inline" ]] ||
  fail "newly installed agent opens in the installation terminal"
pass "missing agents install visibly and open in the same terminal"

: >"$notification_history"
: >"$agent_open_log"
: >"$terminal_log"
MAGIKOS_TEST_AGENT_INSTALLED=true magikos-default-agent agy
[[ ! -s $terminal_log ]] || fail "installed agent selection skips the terminal"
[[ ! -s $notification_history ]] || fail "installed agent selection skips notifications"
mapfile -d '' -t mise_args <"$mise_log"
[[ ${mise_args[0]} == "use" && ${mise_args[1]} == "-g" && ${mise_args[2]} == "antigravity-cli" ]] ||
  fail "default agent still activates an installed provider globally through mise"
mapfile -d '' -t agent_open_args <"$agent_open_log"
[[ ${#agent_open_args[@]} == 1 && ${agent_open_args[0]} == "magikos-agent" ]] ||
  fail "installed agent opens in a new terminal after selection"
pass "installed agents select and open without notifications"

: >"$agent_open_log"
if magikos-default-agent unsupported >"$test_tmp/invalid-output" 2>&1; then
  fail "default agent rejects unsupported providers"
fi
grep -F "Usage: magikos-default-agent" "$test_tmp/invalid-output" >/dev/null ||
  fail "default agent explains supported providers"
[[ $(magikos-default-agent) == "agy" ]] || fail "invalid selection preserves the current default agent"
[[ ! -s $agent_open_log ]] || fail "invalid selection does not open an agent"
pass "default agent rejects unsupported providers without changing the selection"

: >"$notification_history"
: >"$agent_open_log"
if MAGIKOS_TEST_MISE_FAIL=true magikos-default-agent --install opencode >"$test_tmp/install-failure-output" 2>&1; then
  fail "default agent rejects a failed mise installation"
fi
[[ $(magikos-default-agent) == "agy" ]] || fail "failed installation preserves the current default agent"
grep -F "Could not install OpenCode with mise" "$test_tmp/install-failure-output" >/dev/null ||
  fail "default agent reports a failed mise installation in the terminal"
[[ ! -s $notification_history ]] || fail "failed visible agent installation skips notifications"
[[ ! -s $agent_open_log ]] || fail "failed installation does not open an agent"
pass "default agent opens only after mise installs the provider"

: >"$notification_history"
: >"$agent_open_log"
if MAGIKOS_TEST_AGENT_INSTALLED=true MAGIKOS_TEST_MISE_FAIL=true magikos-default-agent opencode >"$test_tmp/setup-failure-output" 2>&1; then
  fail "default agent rejects a failed mise activation"
fi
[[ $(magikos-default-agent) == "agy" ]] || fail "failed activation preserves the current default agent"
grep -F "Could not set OpenCode as the default coding agent" "$test_tmp/setup-failure-output" >/dev/null ||
  fail "default agent reports a failed activation for an installed provider"
[[ ! -s $notification_history ]] || fail "failed activation skips notifications"
[[ ! -s $agent_open_log ]] || fail "failed activation does not open an agent"
pass "default agent reports mise failures without notifications"

rm "$mock_bin/magikos-agent"
hash -r

assert_launched() {
  local agent=$1
  local description=$2
  shift 2
  # Every agent window launches under the same app-id, whichever agent is
  # default, so window rules and themes see one class for all of them.
  local expected=(--app-id=org.magikos.agent "$@")

  mapfile -d '' -t actual <"$launch_log"

  (( ${#actual[@]} == ${#expected[@]} )) ||
    fail "$agent launch $description" "expected: ${expected[*]}\nactual: ${actual[*]}"

  for ((index = 0; index < ${#expected[@]}; index++)); do
    [[ ${actual[$index]} == ${expected[$index]} ]] ||
      fail "$agent launch $description" "expected: ${expected[*]}\nactual: ${actual[*]}"
  done
}

assert_launch() {
  local agent=$1
  shift

  printf '%s\n' "$agent" >"$agent_file"
  magikos-agent-prompt "Review this" project
  assert_launched "$agent" "forwards the interactive prompt" "$@"
}

assert_bypass() {
  local agent=$1
  shift

  printf '%s\n' "$agent" >"$agent_file"
  magikos-agent
  assert_launched "$agent" "skips permission prompts" "$@"
}

assert_launch opencode opencode --auto --prompt "Review this project"
assert_launch agy agy --dangerously-skip-permissions --prompt-interactive "Review this project"
pass "agent launcher adapts initial prompts for every supported agent"

assert_bypass opencode opencode --auto
assert_bypass agy agy --dangerously-skip-permissions
pass "agent launcher skips permission prompts for every supported agent"

printf '%s\n' "opencode" >"$agent_file"
magikos-agent
mapfile -d '' -t launch_args <"$launch_log"
[[ ${launch_args[*]} == "--app-id=org.magikos.agent opencode --auto" ]] ||
  fail "agent launcher starts the selected agent without an initial prompt"
pass "agent launcher starts the selected agent without an initial prompt"

magikos-agent-prompt --inline "Review this project"
mapfile -d '' -t inline_args <"$inline_log"
[[ ${inline_args[*]} == "opencode --auto --prompt Review this project" ]] ||
  fail "inline agent launcher runs in the current terminal"
pass "inline agent launcher runs in the current terminal"

# The prompt route exists so the router can tell a prompt from a subcommand, so
# cover the public routes and not only the binaries behind them.
: >"$launch_log"
magikos agent
mapfile -d '' -t launch_args <"$launch_log"
[[ ${launch_args[*]} == "--app-id=org.magikos.agent opencode --auto" ]] ||
  fail "magikos agent routes to the launcher"

# With an agent chosen there is nothing to pick, so the keybinding launches.
: >"$launch_log"
: >"$menu_log"
magikos-agent --pick
mapfile -d '' -t launch_args <"$launch_log"
[[ ${launch_args[*]} == "--app-id=org.magikos.agent opencode --auto" ]] ||
  fail "--pick launches once an agent is chosen"
[[ ! -s $menu_log ]] || fail "--pick opens no menu once an agent is chosen"
pass "--pick launches once an agent is chosen"

: >"$launch_log"
magikos agent prompt "Review this project"
mapfile -d '' -t launch_args <"$launch_log"
[[ ${launch_args[*]} == "--app-id=org.magikos.agent opencode --auto --prompt Review this project" ]] ||
  fail "magikos agent prompt routes the prompt to the launcher"

: >"$launch_log"
if magikos agent Review this project >"$test_tmp/positional-output" 2>&1; then
  fail "magikos agent rejects a positional prompt"
fi
grep -F "magikos agent prompt" "$test_tmp/positional-output" >/dev/null ||
  fail "magikos agent points a positional prompt at the prompt route"
[[ ! -s $launch_log ]] || fail "magikos agent starts nothing for a positional prompt"
pass "magikos agent keeps prompts on the prompt route"

printf '%s\n' "missing" >"$agent_file"
if MAGIKOS_TEST_MISSING_COMMAND=missing magikos-agent >"$test_tmp/missing-output" 2>&1; then
  fail "agent launcher rejects a missing default command"
fi
grep -F "missing is not installed" "$test_tmp/missing-output" >/dev/null ||
  fail "agent launcher explains when the default command is missing"
pass "agent launcher reports a missing default command"
