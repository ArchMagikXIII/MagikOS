#!/bin/bash

set -euo pipefail

source "$(dirname "$0")/base-test.sh"

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

stub_bin="$tmp_dir/bin"
mkdir -p "$stub_bin"

cat >"$stub_bin/v4l2-ctl" <<'SH'
#!/bin/bash

[[ ${MAGIKOS_TEST_NO_WEBCAM:-false} == "true" ]] && exit 0

case "$1" in
--list-devices)
  printf '%s\n' "ipu6 (PCI:0000:00:05.0):"
  printf '\t%s\n' "/dev/video0"
  printf '\t%s\n' "/dev/video1"

  if [[ ${MAGIKOS_TEST_RAW_WEBCAM:-false} != "true" ]]; then
    printf '\n%s\n' "Built-in Webcam: Integrated Camera"
    printf '\t%s\n' "/dev/video42"
    printf '\t%s\n' "/dev/video43"
    printf '\n%s\n' "USB Capture Card: External Camera"
    printf '\t%s\n' "/dev/video2"
  fi

  if [[ ${MAGIKOS_TEST_DUAL_NODE_WEBCAM:-false} == "true" ]]; then
    printf '\n%s\n' "Dual Node Camera: ISP Wrapper"
    printf '\t%s\n' "/dev/video7"
    printf '\t%s\n' "/dev/video8"
    printf '\n%s\n' "Metadata Only: Sensor"
    printf '\t%s\n' "/dev/video9"
  fi
  ;;
--device)
  case "$2" in
  /dev/video0) device_capability="Video Output" ;;
  /dev/video1) device_capability="Metadata Capture" ;;
  /dev/video7 | /dev/video9) device_capability="Video Output" ;;
  *) device_capability="Video Capture" ;;
  esac

  printf '%s\n' \
    "Driver Info:" \
    $'\tCapabilities     : 0x84a00001' \
    $'\t\tVideo Capture' \
    $'\tDevice Caps      : 0x04200001' \
    $'\t\t'"$device_capability"
  ;;
esac
SH

cat >"$stub_bin/magikos-menu-select" <<'SH'
#!/bin/bash

printf '%s\n' "$@" >"$MAGIKOS_TEST_MENU_ARGS"
printf '%s\n' "$3"
SH

cat >"$stub_bin/magikos-capture-screenrecording" <<'SH'
#!/bin/bash

printf '%s\n' "$@" >"$MAGIKOS_TEST_RECORDER_ARGS"
SH

cat >"$stub_bin/magikos-notification-send" <<'SH'
#!/bin/bash

printf '%s\n' "$@" >"$MAGIKOS_TEST_NOTIFICATION_ARGS"
SH

chmod +x "$stub_bin"/*

export PATH="$stub_bin:$ROOT/bin:$PATH"
# The resize helper anchors to a region file here, so keep it out of the real one
export XDG_RUNTIME_DIR="$tmp_dir"
export MAGIKOS_TEST_MENU_ARGS="$tmp_dir/menu-args"
export MAGIKOS_TEST_RECORDER_ARGS="$tmp_dir/recorder-args"
export MAGIKOS_TEST_NOTIFICATION_ARGS="$tmp_dir/notification-args"

mapfile -t capture_devices < <(magikos-capture-webcam-list)
expected_capture_devices=(
  "/dev/video42  Built-in Webcam: Integrated Camera"
  "/dev/video2  USB Capture Card: External Camera"
)

if [[ ${capture_devices[*]} != "${expected_capture_devices[*]}" ]]; then
  fail "webcam detection filters output-only devices and collapses each capture group" \
    "expected: ${expected_capture_devices[*]}\nactual:   ${capture_devices[*]}"
fi
pass "webcam detection filters output-only devices and collapses each capture group"

dual_node=$(MAGIKOS_TEST_DUAL_NODE_WEBCAM=true magikos-capture-webcam-list) ||
  fail "webcam listing exits zero when the trailing device is filtered"
pass "webcam listing exits zero when the trailing device is filtered"

expected_dual_node="/dev/video42  Built-in Webcam: Integrated Camera
/dev/video2  USB Capture Card: External Camera
/dev/video8  Dual Node Camera: ISP Wrapper"
[[ $dual_node == "$expected_dual_node" ]] ||
  fail "webcam detection falls through to a later capture-capable node in a group" "$dual_node"
pass "webcam detection falls through to a later capture-capable node in a group"

if "$ROOT/bin/magikos-hw-webcam"; then
  pass "webcam hardware detection succeeds when a capture device is available"
else
  fail "webcam hardware detection succeeds when a capture device is available"
fi

if MAGIKOS_TEST_RAW_WEBCAM=true "$ROOT/bin/magikos-hw-webcam"; then
  fail "webcam hardware detection rejects output-only video devices"
else
  pass "webcam hardware detection rejects output-only video devices"
fi

if MAGIKOS_TEST_NO_WEBCAM=true "$ROOT/bin/magikos-hw-webcam"; then
  fail "webcam hardware detection fails when no video device is available"
else
  pass "webcam hardware detection fails when no video device is available"
fi

if MAGIKOS_TEST_RAW_WEBCAM=true "$ROOT/bin/magikos-capture-screenrecording-with-webcam"; then
  fail "screenrecording webcam picker rejects output-only video devices"
fi
grep -Fx 'No webcam devices found' "$MAGIKOS_TEST_NOTIFICATION_ARGS" >/dev/null || \
  fail "screenrecording webcam picker reports no capture-capable device"
pass "screenrecording webcam picker rejects output-only video devices"

"$ROOT/bin/magikos-capture-screenrecording-with-webcam"

expected_menu_args="$tmp_dir/expected-menu-args"
printf '%s\n' \
  "Select Webcam" \
  "/dev/video42  Built-in Webcam: Integrated Camera" \
  "/dev/video2  USB Capture Card: External Camera" \
  "--" \
  "--width" \
  "520" \
  "--maxheight" \
  "520" >"$expected_menu_args"

if ! cmp -s "$MAGIKOS_TEST_MENU_ARGS" "$expected_menu_args"; then
  fail "screenrecording webcam picker passes each webcam as a menu option" "$(diff -u "$expected_menu_args" "$MAGIKOS_TEST_MENU_ARGS")"
fi
pass "screenrecording webcam picker passes each webcam as a menu option"

expected_recorder_args="$tmp_dir/expected-recorder-args"
printf '%s\n' \
  "--with-desktop-audio" \
  "--with-microphone-audio" \
  "--with-webcam" \
  "--webcam-device=/dev/video2" >"$expected_recorder_args"

if ! cmp -s "$MAGIKOS_TEST_RECORDER_ARGS" "$expected_recorder_args"; then
  fail "screenrecording webcam picker starts recording with selected device" "$(diff -u "$expected_recorder_args" "$MAGIKOS_TEST_RECORDER_ARGS")"
fi
pass "screenrecording webcam picker starts recording with selected device"

first_webcam=$(magikos-capture-webcam-list | sed -n '1s/[[:space:]].*//p')
[[ $first_webcam == "/dev/video42" ]] || fail "screenrecording auto-detection selects the first capture device"
grep -F 'WEBCAM_DEVICE=$(magikos-capture-webcam-list' "$ROOT/bin/magikos-capture-screenrecording" >/dev/null || \
  fail "screenrecording auto-detection uses capture-capable webcams"
pass "screenrecording auto-detection uses the first capture-capable webcam"

grep -F -- '--wayland-app-id="WebcamOverlay-$WEBCAM_SIZE"' \
  "$ROOT/bin/magikos-capture-screenrecording" >/dev/null || fail "webcam uses a dedicated size-specific app id"
pass "webcam overlay launches under a dedicated size-specific app id"
