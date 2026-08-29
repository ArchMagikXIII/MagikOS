#!/bin/bash

set -euo pipefail

source "$(dirname "$0")/base-test.sh"

test_tmp=$(mktemp -d)
trap 'rm -rf "$test_tmp"' EXIT

stub_bin="$test_tmp/bin"
mkdir -p "$stub_bin"

# magikos-update delegates the whole update to topgrade. Stub topgrade to
# record the arguments it was handed, and stub the migrate/hook tail that
# follows it so the test exercises only the update path.
topgrade_log="$test_tmp/topgrade"
topgrade_env="$test_tmp/topgrade-env"
cat >"$stub_bin/topgrade" <<'STUB'
#!/bin/bash
printf '%s\n' "$@" >"$TOPGRADE_LOG"
printf '%s\n' "${MAGIKOS_UPDATE_PACMAN:-}" >"$TOPGRADE_ENV"
STUB
for tail_step in magikos-migrate magikos-hook; do
  printf '#!/bin/bash\nexit 0\n' >"$stub_bin/$tail_step"
done
chmod +x "$stub_bin/topgrade" "$stub_bin/magikos-migrate" "$stub_bin/magikos-hook"

# MAGIKOS_UPDATE_LOGGED stands in for the script(1) wrapper the update re-execs
# itself under.
run_update() {
  : >"$test_tmp/topgrade"
  : >"$test_tmp/topgrade-env"
  TOPGRADE_LOG="$test_tmp/topgrade" \
    TOPGRADE_ENV="$test_tmp/topgrade-env" \
    MAGIKOS_UPDATE_LOGGED=1 \
    PATH="$stub_bin:$PATH" bash "$ROOT/bin/magikos-update" "$@"
}

run_update || fail "an update reports a failure when nothing goes wrong"
[[ -f $topgrade_log ]] || fail "magikos-update does not run topgrade"
pass "magikos update runs topgrade"

# The pacman guard hook would block topgrade's internal pacman step, so the
# update must let it through.
[[ $(cat "$test_tmp/topgrade-env") == "1" ]] ||
  fail "magikos update does not let topgrade's pacman step past the guard"
pass "magikos update lets the guard allow topgrade's pacman step"

# Arguments given to magikos update are handed straight to topgrade.
run_update --cleanup
[[ $(cat "$test_tmp/topgrade") == "--cleanup" ]] ||
  fail "magikos update does not pass arguments through to topgrade" "$(cat "$test_tmp/topgrade")"
pass "magikos update forwards arguments to topgrade"
