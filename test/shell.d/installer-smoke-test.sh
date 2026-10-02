#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

installer="$ROOT/installer/magikos-install"
  configurator="$ROOT/installer/configurator"

[[ -x $installer ]] || fail "installer is executable"
pass "installer is executable"

bash -n "$installer" || fail "installer passes a syntax check"
pass "installer parses cleanly"

usage=$("$installer" --help 2>&1) || fail "--help exits zero"
grep -q -- "--disk DEVICE" <<<"$usage" || fail "--help documents --disk" "$usage"
grep -q -- "--backend BE" <<<"$usage" || fail "--help documents --backend" "$usage"
grep -q -- "--existing" <<<"$usage" || fail "--help documents --existing" "$usage"
grep -q -- "--config-file FILE" <<<"$usage" || fail "--help documents --config-file" "$usage"
grep -q -- "--creds-file FILE" <<<"$usage" || fail "--help documents --creds-file" "$usage"
pass "--help prints the option contract"

if "$installer" --bogus >/dev/null 2>&1; then
  fail "unknown option is rejected"
fi
pass "unknown options are rejected"

if grep -q 'OMARCHY_PATH' "$installer"; then
  fail "installer references the old OMARCHY_PATH variable"
fi
pass "installer speaks MAGIKOS_PATH only"

# The skeleton must be assembled the way the magikos-settings package would:
# config/** under .config, bashrc as a dotfile, not a flat default/ dump.
grep -q 'skel/.config' "$installer" || fail "assembles skel .config from config/"
grep -q 'skel/.bashrc' "$installer" || fail "installs default/bashrc as skel .bashrc"
if grep -q 'cp -a "$ROOT/default/." ' "$installer"; then
  fail "no flat default/ copy into skel remains"
fi
pass "skeleton assembly follows the build-time map"

# The orchestrated format is the whole point of the configurator + handoff:
# one final UKI build after every drop-in phase, and a boot validation gate.
grep -q 'finalize_limine_boot' "$installer" || fail "has a single finalize_limine_boot phase" "$installer"
grep -q 'mask_target_boot_hooks' "$installer" || fail "defers boot-image hooks during package phases"
grep -q '^validate_boot()' "$installer" || fail "has a validate_boot gate" "$installer"
grep -q '^create_factory_snapshot()' "$installer" || fail "freezes @factory at the end"
pass "installer phases match the orchestrated format"

# The gum configurator is the brand-new interactive front end and must exist,
# parse cleanly, and hand the orchestrator exactly the files it reads back.
[[ -x $configurator ]] || fail "configurator is executable"
bash -n "$configurator" || fail "configurator passes a syntax check"
grep -q 'user_configuration.json' "$configurator" || fail "configurator writes the install plan"
grep -q 'user_credentials.json' "$configurator" || fail "configurator writes the credentials sidecar"
grep -q 'magikos-install' "$configurator" || fail "configurator execs the orchestrator"
pass "configurator hands off JSON to the orchestrator"

pass "installer smoke tests complete"
