#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

test_tmp=$(mktemp -d)
trap 'rm -rf "$test_tmp"' EXIT

# --- Detection: explicit override wins over whatever is on PATH ---

backend=$(MAGIKOS_PKG_BACKEND=dnf bash -c 'source "$ROOT/bin/magikos-pkg-backend" && echo "$MAGIKOS_PKG_BACKEND"')
[[ $backend == dnf ]] || fail "explicit MAGIKOS_PKG_BACKEND override is honored"
pass "backend honors an explicit override"

# --- Detection: pacman is preferred when both managers exist ---

mock_path="$test_tmp/both-bin"
mkdir -p "$mock_path"
printf '#!/bin/bash\n' >"$mock_path/pacman"
printf '#!/bin/bash\n' >"$mock_path/dnf"
chmod +x "$mock_path/pacman" "$mock_path/dnf"

backend=$(PATH="$mock_path:$PATH" bash -c 'source "$ROOT/bin/magikos-pkg-backend" && echo "$MAGIKOS_PKG_BACKEND"')
[[ $backend == pacman ]] || fail "pacman wins when both backends are present"
pass "backend prefers pacman when both managers exist"

# --- Queries speak rpm on a dnf system ---

run_dnf_script() {
  local script="$1"
  shift
  MAGIKOS_PKG_BACKEND=dnf PATH="$test_tmp/empty-bin:/usr/bin:/bin" \
    bash -c "source \"$ROOT/bin/magikos-pkg-backend\"; $script"
}

mkdir -p "$test_tmp/empty-bin"

cat >"$test_tmp/rpm-log" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >>"$TEST_TMP/rpm-calls"
EOF
cp "$test_tmp/rpm-log" "$test_tmp/empty-bin/rpm"
chmod +x "$test_tmp/empty-bin/rpm"

TEST_TMP="$test_tmp" run_dnf_script 'pkg_installed firefox && pkg_list_installed >/dev/null' >/dev/null
grep -q "^-q firefox$" "$test_tmp/rpm-calls" ||
  fail "pkg_installed queries rpm on dnf systems"
pass "pkg_installed speaks rpm on dnf"

# --- Privileged transaction shapes per backend ---

capture_cmds() {
  local backend="$1" script="$2"
  MAGIKOS_PKG_BACKEND="$backend" bash -c "
    source \"\$ROOT/bin/magikos-pkg-backend\" 2>/dev/null || source \"$ROOT/bin/magikos-pkg-backend\"
    echo \"\${PKG_INSTALL_CMD[*]}\"
    echo \"\${PKG_REMOVE_CMD[*]}\"
  " | sed "s/^env [^ ]* //"
}

cmds=$(MAGIKOS_PKG_BACKEND=pacman bash -c 'source "$ROOT/bin/magikos-pkg-backend"; printf "%s\n%s\n" "${PKG_INSTALL_CMD[*]}" "${PKG_REMOVE_CMD[*]}"')
[[ $(head -1 <<<"$cmds") == "pacman -S --noconfirm --needed" ]] || fail "pacman install shape changed"
[[ $(tail -1 <<<"$cmds") == "pacman -Rns --noconfirm" ]] || fail "pacman remove shape changed"
pass "pacman keeps its historical install/remove shapes"

cmds=$(MAGIKOS_PKG_BACKEND=dnf bash -c 'source "$ROOT/bin/magikos-pkg-backend"; printf "%s\n%s\n" "${PKG_INSTALL_CMD[*]}" "${PKG_REMOVE_CMD[*]}"')
[[ $(head -1 <<<"$cmds") == "dnf install -y" ]] || fail "dnf install shape wrong: $cmds"
[[ $(tail -1 <<<"$cmds") == "dnf remove -y" ]] || fail "dnf remove shape wrong: $cmds"
pass "dnf gets equivalent install/remove shapes"

# --- AUR commands refuse to run on dnf ---

if MAGIKOS_PKG_BACKEND=dnf "$ROOT/bin/magikos-pkg-aur-accessible" >/dev/null 2>"$test_tmp/aur.err"; then
  fail "AUR accessibility check refuses dnf systems"
fi
grep -q "Arch-only" "$test_tmp/aur.err" || fail "AUR refusal explains the Arch-only restriction"
pass "AUR commands refuse dnf systems with a clear message"

# --- update-aur-pkgs skips quietly on dnf ---

out=$(MAGIKOS_PKG_BACKEND=dnf PATH="$ROOT/bin:$PATH" "$ROOT/bin/magikos-update-aur-pkgs" 2>&1)
[[ -z $out ]] || fail "update-aur-pkgs stays quiet on dnf (got: $out)"
pass "AUR updates skip silently on dnf"
