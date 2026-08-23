#!/bin/bash

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  echo "source test/acceptance.d/base-test.sh from an acceptance test; do not run it directly" >&2
  exit 1
fi

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
ARTIFACTS="${MAGIKOS_ACCEPTANCE_DIR:-/tmp/magikos-acceptance}"

mkdir -p "$ARTIFACTS"

pass() {
  printf 'ok - %s\n' "$1"
}

fail() {
  local description="$1"
  local detail="${2:-}"
  local step=${description,,}

  step=${step// /-}
  step=${step//[^a-z0-9-]/}

  [[ -n $detail ]] && printf '%s\n' "$detail" >&2
  screenshot "failure-$step"
  printf 'not ok - %s\n' "$description" >&2
  exit 1
}

screenshot() {
  timeout 10 grim "$ARTIFACTS/$1.png" 2>/dev/null || true
}

screen_contains() {
  local text="$1"
  local snapshot="/tmp/magikos-acceptance-ocr-$$.png"

  if ! timeout 10 grim "$snapshot" 2>/dev/null; then
    rm -f "$snapshot"
    return 1
  fi
  tesseract "$snapshot" stdout --psm 11 2>/dev/null | grep -Fi -- "$text" >/dev/null
  local status=$?
  rm -f "$snapshot"
  return $status
}

# Poll a command until it succeeds; screenshot and fail on timeout.
wait_until() {
  local description="$1" timeout="$2"
  shift 2

  local deadline=$((SECONDS + timeout))

  until "$@" >/dev/null 2>&1; do
    if ((SECONDS >= deadline)); then
      fail "$description" "timed out after ${timeout}s waiting for: $*"
    fi
    sleep 1
  done

  pass "$description"
}

window_present() {
  swaymsg -t get_tree | jq -e --arg class "$1" '
    [.. | objects | select(
      ((.app_id? // "") | test($class)) or
      ((.window_properties.class? // "") | test($class))
    )] | length > 0
  '
}

window_absent() {
  ! window_present "$1"
}

# Sway's IPC exposes no layer surfaces, so layer visibility is checked with
# pixels: compare the current screen against a reference captured while every
# surface is hidden. The reference starts as whatever was on screen when the
# suite booted and refreshes after every successful absence probe, so a clock
# or wallpaper change cannot accumulate into a false "present". Namespace is
# kept in the signature for readability; any visible difference counts.
LAYER_DIFF_THRESHOLD=${MAGIKOS_ACCEPTANCE_LAYER_DIFF_PIXELS:-4000}

refresh_absent_reference() {
  timeout 10 grim "$ARTIFACTS/absent-screen-reference.png" 2>/dev/null || true
}

changed_pixels() {
  local reference="$1" candidate="$2"

  # AE prints the changed pixel count; a size mismatch prints an error, which
  # reads as "everything changed" and fails the check that asked.
  magick compare -metric AE -fuzz 10% "$reference" "$candidate" null: 2>&1 || true
}

screen_differs_from() {
  local reference="$1"
  local snapshot="/tmp/magikos-acceptance-compare-$$.png"
  local diff

  timeout 10 grim "$snapshot" 2>/dev/null || return 1
  diff=$(changed_pixels "$reference" "$snapshot")
  rm -f "$snapshot"

  [[ ${diff%%[^0-9]*} =~ ^[0-9]+$ ]] || return 0
  (( ${diff%%[^0-9]*} > LAYER_DIFF_THRESHOLD ))
}

screen_matches() {
  ! screen_differs_from "$1"
}

layer_present() {
  [[ -s $ARTIFACTS/absent-screen-reference.png ]] || refresh_absent_reference
  [[ -s $ARTIFACTS/absent-screen-reference.png ]] || return 1

  screen_differs_from "$ARTIFACTS/absent-screen-reference.png"
}

layer_absent() {
  if layer_present "$1"; then
    return 1
  fi

  refresh_absent_reference
}

# Close every window matching a class regex, by container id so multi-window
# apps are fully closed.
close_windows() {
  local class="$1"
  local con_id

  while read -r con_id; do
    swaymsg "[con_id=$con_id] kill" >/dev/null 2>&1 || true
  done < <(swaymsg -t get_tree | jq -r --arg class "$class" '
    [.. | objects | select(
      ((.app_id? // "") | test($class)) or
      ((.window_properties.class? // "") | test($class))
    ) | .id]
  ')
}

launch_app() {
  setsid -f bash -c "$1" >/dev/null 2>&1
}
