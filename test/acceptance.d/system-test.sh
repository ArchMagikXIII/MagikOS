#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

status=0

verify_core_packages() {
  local package
  local -a missing=()

  while IFS= read -r package; do
    [[ -z $package || $package == \#* ]] && continue
    pacman -Q "$package" >/dev/null 2>&1 || missing+=("$package")
  done <"$MAGIKOS_PATH/install/magikos-base.packages"

  (( ${#missing[@]} == 0 )) || fail "all Magikos core packages are installed" "missing packages: ${missing[*]}"
  pass "all Magikos core packages are installed (${#missing[@]} missing)"
}

verify_defaults() {
  [[ $(magikos-default-browser) == "brave-origin" ]] || fail "Brave Origin is the default browser"
  pass "Brave Origin is the default browser"

  [[ $(magikos-default-terminal) == "foot" ]] || fail "Foot is the default terminal"
  pass "Foot is the default terminal"

  [[ $(magikos-default-editor) == "nvim" ]] || fail "Neovim is the default editor"
  pass "Neovim is the default editor"

  [[ $(magikos-theme-current) != "Unknown" ]] || fail "a current theme is configured"
  pass "a current theme is configured"

  [[ $(magikos-theme-bg-current) != "Unknown" ]] || fail "a current background is configured"
  pass "a current background is configured"

  [[ -n $(magikos-font-current) ]] || fail "a monospace font is configured"
  pass "a monospace font is configured"

  [[ $(xdg-mime query default x-scheme-handler/http) == "brave-origin.desktop" ]] || fail "HTTP MIME handling uses Brave Origin"
  pass "desktop MIME handlers are configured"
}

verify_services() {
  local unit

  for unit in \
    avahi-daemon.service NetworkManager.service power-profiles-daemon.service \
    sddm.service systemd-resolved.service ufw.service; do
    systemctl is-enabled --quiet "$unit" || fail "core system services are enabled" "$unit is not enabled"
  done
  pass "core system services are enabled"

  for unit in NetworkManager.service systemd-resolved.service ufw.service; do
    systemctl is-active --quiet "$unit" || fail "critical system services are running" "$unit is not active"
  done
  pass "critical system services are running"

  systemctl --user is-active --quiet pipewire.service pipewire-pulse.service wireplumber.service ||
    fail "user audio services are running"
  pass "user audio services are running"
}

verify_runtime_tools() {
  nvim --headless '+qa' >/dev/null 2>&1 || fail "Neovim starts headlessly"
  pass "Neovim starts headlessly"

  timeout 10 fastfetch --pipe false >/dev/null 2>&1 || fail "Fastfetch can read system information"
  pass "Fastfetch can read system information"

  git --version >/dev/null || fail "Git is installed and runnable"
  mise --version >/dev/null || fail "Mise is installed and runnable"
  pass "core terminal tools are runnable"
}

verify_user_setup() {
  local directory

  for directory in DESKTOP DOCUMENTS DOWNLOAD PICTURES; do
    [[ -d $(xdg-user-dir "$directory") ]] || fail "XDG user directories exist" "$directory is missing"
  done
  pass "XDG user directories exist"

  [[ -e $HOME/.local/state/magikos/current/theme ]] || fail "current theme state exists"
  [[ -e $HOME/.local/state/magikos/current/background ]] || fail "current background state exists"
  [[ -s $HOME/.config/magikos/shell.json ]] || fail "shell configuration exists"
  jq empty "$HOME/.config/magikos/shell.json" || fail "shell configuration is valid JSON"
  pass "Magikos user state and shell configuration exist"
}

for check in verify_core_packages verify_defaults verify_services verify_runtime_tools verify_user_setup; do
  if ! ("$check"); then
    status=1
  fi
done

exit $status
