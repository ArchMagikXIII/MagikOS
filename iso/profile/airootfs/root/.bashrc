# Print a one-line pointer on interactive live root shells.
if [[ -t 0 ]] && [[ -d /root/magikos ]]; then
  printf '%s\n' 'MagikOS live medium: run "bash /root/magikos/installer/magikos-install" to install.'
fi