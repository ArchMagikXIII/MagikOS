# Run the archiso-style automated_script hook from a bash login shell. The
# stock releng profile only wires it into zsh's .zlogin, but this ISO pins
# root's shell to /usr/bin/bash, so the live autologin would otherwise never
# reach the MagikOS configurator.
if [[ -f ~/.automated_script.sh ]]; then
  bash ~/.automated_script.sh
fi