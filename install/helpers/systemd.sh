# Init system detection and service management for Magikos installer
#
# Provides detection and service enable/disable/mask operations for systemd,
# OpenRC, and runit. This helper alone does not make the installer or the
# Arch/CachyOS package set compatible with Artix.
#
# Environment variables:
#   MAGIKOS_NO_SYSTEMD=1  - Force-disable systemd operations
#   MAGIKOS_NO_OPENRC=1   - Force-disable OpenRC operations
#   MAGIKOS_NO_RUNIT=1   - Force-disable runit operations
#   MAGIKOS_OPENRC_INIT_DIR - Override /etc/init.d (for isolated tests)

# --- Detection ---

magikos_has_systemd() {
  if [[ "${MAGIKOS_NO_SYSTEMD:-0}" == "1" ]]; then
    return 1
  fi
  if [[ -d /run/systemd/system ]]; then
    return 0
  fi
  if command -v systemctl >/dev/null 2>&1; then
    if systemctl is-system-running &>/dev/null || \
       systemctl is-system-running 2>/dev/null | grep -qE "running|degraded"; then
      return 0
    fi
  fi
  return 1
}

magikos_has_openrc() {
  if [[ "${MAGIKOS_NO_OPENRC:-0}" == "1" ]]; then
    return 1
  fi
  command -v rc-update >/dev/null 2>&1 && [[ -d ${MAGIKOS_OPENRC_INIT_DIR:-/etc/init.d} ]]
}

# Unit names are not necessarily OpenRC init script names (Artix BlueZ ships
# /etc/init.d/bluetoothd, not bluetooth). Leave systemd names untouched on the
# systemd path; only use this translation when talking to OpenRC.
magikos_openrc_service_name() {
  local name="${1%.service}"
  case "$name" in
    bluetooth) name=bluetoothd ;;
  esac
  printf '%s\n' "$name"
}

magikos_openrc_runlevel() {
  case "$1" in
    elogind) printf 'boot\n' ;;
    *) printf 'default\n' ;;
  esac
}

magikos_openrc_has_service() {
  [[ -f "${MAGIKOS_OPENRC_INIT_DIR:-/etc/init.d}/$1" ]]
}

magikos_has_runit() {
  if [[ "${MAGIKOS_NO_RUNIT:-0}" == "1" ]]; then
    return 1
  fi
  command -v runsv >/dev/null 2>&1 && [[ -d /etc/sv || -d /etc/runit/sv ]]
}

# --- Service operations ---

# Enable a service (start at boot)
magikos_service_enable() {
  local service="$1"

  if magikos_has_systemd; then
    systemctl enable "$service" 2>/dev/null || true
  elif magikos_has_openrc; then
    local name runlevel
    name=$(magikos_openrc_service_name "$service")
    if magikos_openrc_has_service "$name"; then
      runlevel=$(magikos_openrc_runlevel "$name")
      rc-update add "$name" "$runlevel" || return
      # Artix expects elogind in boot, not also in default. This only changes
      # boot links; it does not touch a daemon running in the live environment.
      if [[ $name == elogind ]]; then
        rc-update del elogind default >/dev/null 2>&1 || true
      fi
    else
      echo "$name not installed; skipping"
    fi
  elif magikos_has_runit; then
    if [[ -d "/etc/sv/$service" ]]; then
      mkdir -p /etc/service
      ln -sf "/etc/sv/$service" "/etc/service/$service"
    fi
  else
    echo "No init system found; cannot enable $service"
  fi
}

# Disable a service (don't start at boot)
magikos_service_disable() {
  local service="$1"

  if magikos_has_systemd; then
    systemctl disable "$service" 2>/dev/null || true
  elif magikos_has_openrc; then
    local name
    name=$(magikos_openrc_service_name "$service")
    if magikos_openrc_has_service "$name"; then
      rc-update del "$name" "$(magikos_openrc_runlevel "$name")" 2>/dev/null || true
    fi
  elif magikos_has_runit; then
    rm -f "/etc/service/$service"
  fi
}

# Mask a service (prevent from starting)
magikos_service_mask() {
  local service="$1"

  if magikos_has_systemd; then
    systemctl mask "$service" 2>/dev/null || true
  elif magikos_has_openrc; then
    # OpenRC has no mask equivalent; only disable real init scripts.
    local name
    name=$(magikos_openrc_service_name "$service")
    if magikos_openrc_has_service "$name"; then
      rc-update del "$name" "$(magikos_openrc_runlevel "$name")" 2>/dev/null || true
    fi
  elif magikos_has_runit; then
    rm -f "/etc/service/$service"
  fi
}

# Check if a service is active
magikos_service_is_active() {
  local service="$1"

  if magikos_has_systemd; then
    systemctl is-active --quiet "$service" 2>/dev/null
  elif magikos_has_openrc; then
    local name
    name=$(magikos_openrc_service_name "$service")
    magikos_openrc_has_service "$name" && rc-service "$name" status 2>/dev/null | grep -q "started"
  elif magikos_has_runit; then
    [[ -d "/etc/service/$service" ]] && sv status "$service" 2>/dev/null | grep -q "run"
  else
    return 1
  fi
}

# Stop a service
magikos_service_stop() {
  local service="$1"

  if magikos_has_systemd; then
    systemctl stop "$service" 2>/dev/null || true
  elif magikos_has_openrc; then
    local name
    name=$(magikos_openrc_service_name "$service")
    if magikos_openrc_has_service "$name"; then
      rc-service "$name" stop 2>/dev/null || true
    fi
  elif magikos_has_runit; then
    sv stop "$service" 2>/dev/null || true
  fi
}

# --- Convenience ---

magikos_skip_systemd() {
  local reason="${1:-systemd not available}"
  echo "Skipping systemd operation: $reason"
}

# Detect which init system is available and print it
magikos_detect_init() {
  if magikos_has_systemd; then
    echo "systemd"
  elif magikos_has_openrc; then
    echo "openrc"
  elif magikos_has_runit; then
    echo "runit"
  else
    echo "unknown"
  fi
}
