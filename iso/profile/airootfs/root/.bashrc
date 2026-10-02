# Print a one-line pointer on interactive live root shells.
if [[ -t 0 ]] && [[ -d /root/magikos ]]; then
  printf '%s\n' 'MagikOS live medium: run "MagikOS-Install --disk /dev/sdX --user NAME" to install.'
fi