# Distribution checks shared by the installer and post-install scripts.
# Read the target's os-release, not the live install medium's init state.
magikos_is_artix() {
  local release=${MAGIKOS_OS_RELEASE:-/etc/os-release}
  if [[ ! -r $release && -z ${MAGIKOS_OS_RELEASE:-} ]]; then
    release=/usr/lib/os-release
  fi
  [[ -r $release ]] && grep -Eq '^ID="?artix"?$' "$release"
}
