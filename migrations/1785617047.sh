echo "Install oh-my-pi (omp) via mise wrapper"

if [[ ! -f $HOME/.local/state/magikos/preinstalls-removed ]]; then
  magikos-mise-install github:can1357/oh-my-pi omp
fi
