#!/bin/bash

# Select bar during user provisioning. Non-interactive by default (QuickShell);
# called with --interactive from magikos-provision-user to prompt the user.

set -euo pipefail

MAGIKOS_PATH="${MAGIKOS_PATH:-/usr/share/magikos}"

interactive=0
while (($#)); do
  case "$1" in
  --interactive) interactive=1; shift ;;
  *) shift ;;
  esac
done

if (( interactive )) && [[ -t 0 ]]; then
  bash "$MAGIKOS_PATH/bin/magikos-select-bar"
else
  # Default to QuickShell in non-interactive installs
  bash "$MAGIKOS_PATH/bin/magikos-select-bar" quickshell
fi
