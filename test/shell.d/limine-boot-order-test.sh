#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

packaged_defaults="$ROOT/etc/limine-entry-tool.d/magikos-defaults.conf"
expected='BOOT_ORDER="linux-t2, linux-omarchy, linux-omarchy-*, *, *fallback, Snapshots"'

grep -Fxq "$expected" "$packaged_defaults" ||
  fail "packaged Limine defaults protect T2 Macs and prefer the exact Omarchy kernel elsewhere"
pass "packaged Limine defaults protect T2 Macs and prefer the exact Omarchy kernel elsewhere"

grep -Fq 'BOOT_ORDER=\"linux-t2, linux-omarchy, linux-omarchy-*, *, *fallback, Snapshots\"' "$ROOT/installer/magikos-install" ||
  fail "fresh installs prefer the Omarchy kernel with the T2 exception"
pass "fresh installs prefer the Omarchy kernel with the T2 exception"

grep -Fxq "linux-omarchy" "$ROOT/install/magikos-base.packages" ||
  fail "magikos-base.packages ships the Omarchy kernel"
pass "magikos-base.packages ships the Omarchy kernel"

grep -Fxq "linux-omarchy-headers" "$ROOT/install/magikos-base.packages" ||
  fail "magikos-base.packages ships matching Omarchy kernel headers"
pass "magikos-base.packages ships matching Omarchy kernel headers"
