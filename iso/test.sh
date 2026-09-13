#!/bin/bash
# Build a MagikOS live ISO with the smoke-check overlay baked in, boot it in
# QEMU/KVM, and assert the markers. Needs root (for the build), archiso,
# squashfs-tools, rsync, qemu-system-x86_64, and /dev/kvm.
set -euo pipefail

REPO="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUN_DIR="$REPO/iso/test-runs/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$RUN_DIR"

echo "==> Building the smoke-test ISO variant"
"$REPO/iso/build.sh" \
  --out-dir "$RUN_DIR" \
  --extra-overlay "$REPO/iso/test/overlay" \
  --boot-console ttyS0

shopt -s nullglob
iso_files=("$RUN_DIR"/*.iso)
shopt -u nullglob
(( ${#iso_files[@]} == 1 )) || { echo "expected exactly one ISO in $RUN_DIR" >&2; exit 1; }
ISO=${iso_files[0]}

echo "==> Booting $ISO in QEMU ($RUN_DIR)"
truncate -s 20G "$RUN_DIR/disk.img"
qemu-system-x86_64 \
  -machine pc,accel=kvm -cpu host -m 4096 -smp 2 \
  -display none -monitor none -no-reboot \
  -serial file:"$RUN_DIR/serial.log" \
  -boot d -cdrom "$ISO" \
  -drive file="$RUN_DIR/disk.img",if=virtio,format=raw,media=disk \
  -netdev user,id=net0 -device virtio-net-pci,netdev=net0 \
  -pidfile "$RUN_DIR/qemu.pid" &
QEMU_PID=$!

fails=0
for _ in $(seq 1 100); do
  if grep -q "SMOKE_DONE" "$RUN_DIR/serial.log" 2>/dev/null; then
    break
  fi
  kill -0 "$QEMU_PID" 2>/dev/null || { echo "QEMU exited before SMOKE_DONE" >&2; fails=1; break; }
  sleep 3
done

kill "$QEMU_PID" 2>/dev/null || true
wait "$QEMU_PID" 2>/dev/null || true

check() {
  if grep -q "$2" "$RUN_DIR/serial.log" 2>/dev/null; then
    echo "ok - $1"
  else
    echo "FAIL - $1"
    fails=1
  fi
}

check "live environment booted (SMOKE_START)"        "SMOKE_START"
check "kernel came up (SMOKE_KERNEL)"                "SMOKE_KERNEL"
check "repo bundled at /root/magikos"                "SMOKE_REPO_BUNDLED_OK"
check "bundled magikos command is executable"        "SMOKE_BIN_EXEC_OK"
check "installer script is syntactically valid"      "SMOKE_INSTALLER_SYNTAX_OK"
check "smoke check finished (SMOKE_DONE)"            "SMOKE_DONE"

if grep -q "SMOKE_INSTALLER_SYNTAX_FAIL" "$RUN_DIR/serial.log" 2>/dev/null; then
  echo "FAIL - installer syntax check ran and failed"
  fails=1
fi

if (( fails )); then
  echo "==> serial.log tail:"
  tail -40 "$RUN_DIR/serial.log" 2>/dev/null || true
  exit 1
fi

echo "==> Smoke test passed: $(grep -o 'SMOKE_KERNEL .*' "$RUN_DIR/serial.log" | tail -1)"
echo "    Logs: $RUN_DIR/serial.log"