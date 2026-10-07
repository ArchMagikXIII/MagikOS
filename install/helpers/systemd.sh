# systemd detection helper for Magikos installer
#
# Provides magikos_has_systemd() so installer leaves can gate systemd-specific
# operations (systemctl enable/disable/mask, writing unit files, etc.) on
# whether the target system actually runs systemd. This allows the installer
# to work on Artix Linux and other Arch-based distributions that use
# alternative init systems (OpenRC, runit, s6, etc.).
#
# Set MAGIKOS_NO_SYSTEMD=1 to force-disable systemd operations regardless
# of detection (useful for testing or when detection fails).

magikos_has_systemd() {
  # Explicit override takes precedence
  if [[ "${MAGIKOS_NO_SYSTEMD:-0}" == "1" ]]; then
    return 1
  fi

  # Check if systemd is the running init (PID 1)
  if [[ -d /run/systemd/system ]]; then
    return 0
  fi

  # Check if systemctl exists and works
  if command -v systemctl >/dev/null 2>&1; then
    # systemctl exists but systemd may not be PID 1 (e.g., in a chroot)
    # Try a quick operation to verify it actually works
    if systemctl is-system-running &>/dev/null || \
       systemctl is-system-running 2>/dev/null | grep -qE "running|degraded"; then
      return 0
    fi
  fi

  return 1
}

# Convenience: log a message when systemd operations are skipped
magikos_skip_systemd() {
  local reason="${1:-systemd not available}"
  echo "Skipping systemd operation: $reason"
}
