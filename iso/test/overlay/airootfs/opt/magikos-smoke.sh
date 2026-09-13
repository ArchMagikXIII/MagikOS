#!/bin/bash
# Boot-time smoke check for the MagikOS live ISO (test builds only).
# Writes one-line markers to the serial console so a headless QEMU run can
# assert that the image booted, the repo bundle was mounted, and the installer
# script is syntactically valid.
set -u

out() {
  printf '%s\n' "$*" >/dev/ttyS0 2>/dev/null || printf '%s\n' "$*" >/dev/kmsg
}

out "SMOKE_START $(date -Is)"
out "SMOKE_KERNEL $(uname -r)"
if [[ -f /root/magikos/installer/magikos-install ]]; then
  out "SMOKE_REPO_BUNDLED_OK"
  if [[ -x /root/magikos/bin/magikos ]]; then
    out "SMOKE_BIN_EXEC_OK"
  else
    out "SMOKE_BIN_EXEC_MISSING"
  fi
  if bash -n /root/magikos/installer/magikos-install; then
    out "SMOKE_INSTALLER_SYNTAX_OK"
  else
    out "SMOKE_INSTALLER_SYNTAX_FAIL"
  fi
else
  out "SMOKE_REPO_BUNDLED_MISSING"
fi
out "SMOKE_DONE"