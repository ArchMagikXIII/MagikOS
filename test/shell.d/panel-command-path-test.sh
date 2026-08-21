#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

if matches=$(rg -n 'root\.bar\.magikosPath|/bin/magikos-' "$ROOT/shell/plugins/panels" -g '*.qml'); then
  fail "panels do not resolve magikos helpers through bar paths" "$matches"
fi

pass "panels avoid bar path resolution for magikos helpers"
