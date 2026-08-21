echo "Install hey (hey-cli) via mise wrapper"

if [[ ! -f $HOME/.local/state/magikos/preinstalls-removed ]]; then
  magikos-mise-install github:basecamp/hey-cli hey
fi
