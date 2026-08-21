#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

TMPDIR=""

export PATH="$ROOT/bin:$PATH"

cleanup() {
  if [[ -n $TMPDIR && -d $TMPDIR ]]; then
    rm -rf "$TMPDIR"
  fi
}
trap cleanup EXIT

require_command jq

TMPDIR=$(mktemp -d)
test_home="$TMPDIR/home"
manifest_path="$test_home/.config/chromium/NativeMessagingHosts/com.magikos.ytdlp.json"

HOME="$test_home" MAGIKOS_PATH="$ROOT" magikos-install-chromium-ytdlp

[[ -f $manifest_path ]] || fail "yt-dlp native host installer creates fresh Chromium profile root"
pass "yt-dlp native host installer creates fresh Chromium profile root"

jq -e --arg path "$ROOT/bin/magikos-chromium-ytdlp-host" '
  .name == "com.magikos.ytdlp" and
  .path == $path and
  (.allowed_origins | index("chrome-extension://dedjgknigfeelejglamclffonmophnfl/"))
' "$manifest_path" >/dev/null
pass "yt-dlp native host manifest uses Magikos host path and extension id"

parse_result=$(bash -c '
  MAGIKOS_PATH="$3"
  source "$1"
  parse_url "$2"
' bash "$ROOT/bin/magikos-chromium-ytdlp-host" '{"url":"https://example.test/watch?v=\"quoted\"&name=a\\b"}' "$ROOT")

[[ $parse_result == "https://example.test/watch?v=\"quoted\"&name=a\\b" ]] ||
  fail "yt-dlp native host parses escaped JSON URLs" "$parse_result"
pass "yt-dlp native host parses escaped JSON URLs"

bash -c '
  MAGIKOS_PATH="$3"
  source "$1"
  valid_url "$2"
' bash "$ROOT/bin/magikos-chromium-ytdlp-host" "javascript:alert(1)" "$ROOT" &&
  fail "yt-dlp native host rejects non-web URLs"
pass "yt-dlp native host rejects non-web URLs"
