#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

# Each argument is a PCI device as "vendor:class", in sysfs's own format.
write_pci_devices() {
  rm -rf "$tmp_dir/devices"
  mkdir -p "$tmp_dir/devices"

  local index=0
  local spec
  for spec in "$@"; do
    local slot
    slot=$(printf '0000:%02x:00.0' "$index")
    mkdir -p "$tmp_dir/devices/$slot"
    printf '%s\n' "${spec%%:*}" >"$tmp_dir/devices/$slot/vendor"
    printf '%s\n' "${spec##*:}" >"$tmp_dir/devices/$slot/class"
    index=$((index + 1))
  done
}

hw_nvidia_powerd() {
  MAGIKOS_PCI_DEVICES_PATH="$tmp_dir/devices" "$ROOT/bin/magikos-hw-nvidia-powerd"
}

assert() {
  local description="$1" expected="$2"

  local actual=no
  hw_nvidia_powerd && actual=yes

  [[ $actual == "$expected" ]] ||
    fail "$description" "magikos-hw-nvidia-powerd: expected $expected, got $actual"

  pass "$description"
}

# AMD Renoir iGPU alone: no NVIDIA, nothing to power down.
write_pci_devices 0x1002:0x1636:0x030000
assert "an integrated-only machine does not need nvidia-powerd" no

# NVIDIA GTX 1650 Mobile alongside AMD Renoir, the pair from this laptop.
write_pci_devices 0x1002:0x1636:0x030000 0x10de:0x1f99:0x030000
assert "a hybrid laptop enables nvidia-powerd" yes

# NVIDIA as the only display GPU: a desktop, runtime DPM is meaningless.
write_pci_devices 0x10de:0x1f99:0x030000
assert "an NVIDIA-only desktop does not need nvidia-powerd" no

# Two NVIDIA GPUs with no other brand: still not an offload/PRIME setup.
write_pci_devices 0x10de:0x1f99:0x030000 0x10de:0x2560:0x030200
assert "dual-NVIDIA without an iGPU is not a hybrid offload laptop" no

# NVIDIA GPU plus a non-display NVIDIA audio function (class 0x04): the audio
# function is not a second GPU, so this is still an NVIDIA-only machine.
write_pci_devices 0x10de:0x1f99:0x030000 0x10de:0x228e:0x040300
assert "an NVIDIA audio function is not a second display GPU" no

write_pci_devices
assert "a machine with no PCI devices does not need nvidia-powerd" no
