echo "Retire AI tools outside OpenCode and Antigravity"

# Magikos now ships only the opencode and agy (Antigravity) coding agents.
# Everything else AI -- retired CLIs, their launchers and state, the
# subscription-usage collectors and bar panel, the desktop AI apps, and local
# LLM runners -- goes, the same way a fresh install no longer creates it.
# Every step tolerates an already-clean system so reruns are no-ops.

# Retired mise tools. unuse drops the global pin, uninstall removes the
# download; neither fails when the tool was never installed.
if command -v mise >/dev/null 2>&1; then
  for tool in claude codex crush copilot pi "github:can1357/oh-my-pi" "npm:@xai-official/grok"; do
    mise unuse -g "$tool" >/dev/null 2>&1 || true
    mise uninstall "$tool" >/dev/null 2>&1 || true
  done
fi
rm -rf "$HOME/.local/share/mise/downloads/codex"

# Retired lazy stubs. Anchored to the installer-written mise line, so a
# hand-written wrapper that merely mentions the package is left alone. Both
# the bare and the fully qualified backend forms count as installer-written.
retired_shim() {
  local wrapper="$HOME/.local/bin/$1"
  if [[ -f $wrapper ]] && grep -Eq "^mise use -g .*\"$2\"" "$wrapper"; then
    rm -f "$wrapper"
  fi
}
retired_shim codex "codex"
retired_shim claude "claude"
retired_shim crush "crush"
retired_shim copilot "copilot"
retired_shim pi "pi"
retired_shim omp "(github:can1357/)?oh-my-pi"
retired_shim grok "(npm:)?@xai-official/grok"

# Retired harness state. ~/.agents/skills and ~/.gemini/config/skills stay:
# provision-user keeps them linked for the agents that remain.
rm -rf "$HOME/.claude" "$HOME/.codex" "$HOME/.cline" "$HOME/.openhands" \
  "$HOME/.pi" "$HOME/.grok" "$HOME/.claude.json" "$HOME/.cache/codex-runtimes"

# Usage records and scanner caches have no collectors or panel left to read
# them, so the staleness they guarded against no longer applies.
rm -rf "$HOME/.local/state/magikos/agents" "$HOME/.cache/magikos/agent-usage"

# A default naming a retired agent would leave the launcher with nothing to
# start, so remap it to whichever supported agent is installed.
agent_file="$HOME/.config/magikos/defaults/agent"
if [[ -f $agent_file ]]; then
  selected_agent=""
  read -r selected_agent <"$agent_file" || true
  case "$selected_agent" in
  pi | omp | oh-my-pi | claude | claude-code | codex | crush | grok | copilot | github-copilot)
    if ! magikos-cmd-missing opencode; then
      printf '%s\n' opencode >"$agent_file"
    elif ! magikos-cmd-missing agy; then
      printf '%s\n' agy >"$agent_file"
    fi
    ;;
  esac
fi

# Drop the retired bar widget from existing layouts. Unparsable configs are
# left alone rather than truncated.
shell_json="$HOME/.config/magikos/shell.json"
if command -v jq >/dev/null 2>&1 && [[ -f $shell_json ]] && jq -e . "$shell_json" >/dev/null 2>&1; then
  tmp_json=$(mktemp)
  if jq '(.bar.layout.left // empty) |= map(select(if type == "string" then . != "magikos.agents" else .id != "magikos.agents" end))
    | (.bar.layout.center // empty) |= map(select(if type == "string" then . != "magikos.agents" else .id != "magikos.agents" end))
    | (.bar.layout.right // empty) |= map(select(if type == "string" then . != "magikos.agents" else .id != "magikos.agents" end))
    | (.disabledPlugins // empty) |= map(select(. != "magikos.agents"))' "$shell_json" >"$tmp_json" 2>/dev/null &&
    ! cmp -s "$shell_json" "$tmp_json"; then
    cat "$tmp_json" >"$shell_json"
  fi
  rm -f "$tmp_json"
fi

# Retired desktop AI apps and local LLM runners with their models and data.
sudo systemctl disable --now ollama.service >/dev/null 2>&1 || true
magikos-pkg-drop ollama ollama-cuda ollama-rocm ollama-vulkan >/dev/null 2>&1 || true
sudo rm -rf /var/lib/ollama || true
rm -rf "$HOME/.ollama"

magikos-pkg-drop openai-codex-desktop >/dev/null 2>&1 || true
rm -rf "$HOME/.config/Codex" "$HOME/.cache/Codex"

magikos-pkg-drop grok-bot >/dev/null 2>&1 || true
rm -rf "$HOME/.config/Grok Bot" "$HOME/.grokbot"

magikos-pkg-drop lmstudio-bin >/dev/null 2>&1 || true
lmstudio_home=""
if [[ -f $HOME/.lmstudio-home-pointer ]]; then
  read -r lmstudio_home <"$HOME/.lmstudio-home-pointer" || true
fi
rm -rf "$HOME/.config/LM Studio" "$HOME/.config/LM-Studio" "$HOME/.lmstudio" "$HOME/.lmstudio-home-pointer"
if [[ -n $lmstudio_home && $lmstudio_home == /* && -d $lmstudio_home ]] &&
  [[ $lmstudio_home != "/" && $lmstudio_home != "$HOME" ]]; then
  rm -rf "$lmstudio_home"
fi

magikos-pkg-drop t3code-bin >/dev/null 2>&1 || true
rm -rf "$HOME/.config/t3code" "$HOME/.t3"
rm -f "$HOME/.config/t3code-flags.conf"

# Retired global npm CLIs. The prefix is root-owned, so this needs sudo and
# quietly skips when it cannot authenticate.
sudo npm uninstall -g cline @openhands/agent-canvas >/dev/null 2>&1 || true
