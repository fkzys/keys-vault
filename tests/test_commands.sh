#!/usr/bin/env bash
# tests/test_commands.sh — Command behavior with mocked external tools
# Run: bash tests/test_commands.sh

source "$(dirname "${BASH_SOURCE[0]}")/test_harness.sh"

VAULT="${PROJECT_ROOT}/bin/keys-vault"

# ── Setup ─────────────────────────────────────────────────────

MOCK_STATE="${TESTDIR}/mock_state"
mkdir -p "$MOCK_STATE" "${TESTDIR}/no_config"

# gocryptfs: on -init create gocryptfs.conf, always consume stdin
# Emits the master-key banner unless -q, so init tests can assert it is surfaced.
make_mock_in "${MOCK_BIN}" gocryptfs '
cat > /dev/null 2>/dev/null
_dir="" _init=0 _sep=0 _quiet=0
for _a in "$@"; do
    [[ "$_a" == "-init" ]] && _init=1
    [[ "$_a" == "-q" || "$_a" == "-quiet" ]] && _quiet=1
    [[ "$_a" == "--" ]] && { _sep=1; continue; }
    [[ $_sep -eq 1 && -z "$_dir" ]] && _dir="$_a"
done
if [[ $_init -eq 1 && -n "$_dir" ]]; then
    mkdir -p "$_dir"
    touch "${_dir}/gocryptfs.conf"
fi
if [[ $_quiet -eq 0 ]]; then
    echo "Your master key is:"
    echo "    deadbeef-deadbeef-deadbeef-deadbeef-deadbeef-deadbeef-deadbeef-deadbeef"
fi
exit 0'

# secret-tool: store consumes stdin, lookup returns passphrase
make_mock_in "${MOCK_BIN}" secret-tool '
case "$1" in
    store)  cat > /dev/null ;;
    lookup) echo "mock-passphrase" ;;
esac
exit 0'

# timeout: transparent pass-through
make_mock_in "${MOCK_BIN}" timeout '
shift
exec "$@"'

# fusermount: always succeed
make_mock_in "${MOCK_BIN}" fusermount 'exit 0'

# mountpoint: controlled by state file
make_mock_in "${MOCK_BIN}" mountpoint "
if [[ -f '${MOCK_STATE}/mounted' ]]; then exit 0; else exit 1; fi"

# ── Helpers ───────────────────────────────────────────────────

set_mounted()   { touch "${MOCK_STATE}/mounted"; }
set_unmounted() { rm -f "${MOCK_STATE}/mounted"; }

# Run vault with mocks, no user config, custom test dir
run_vault() {
    _rc=0
    _out=$(env PATH="${MOCK_BIN}:${ORIG_PATH}" \
               XDG_CONFIG_HOME="${TESTDIR}/no_config" \
               bash "$VAULT" "$@" 2>&1) || _rc=$?
}

# Run vault with stdin input
run_vault_input() {
    local input="$1"; shift
    _rc=0
    _out=$(printf '%s' "$input" | env PATH="${MOCK_BIN}:${ORIG_PATH}" \
                                      XDG_CONFIG_HOME="${TESTDIR}/no_config" \
                                      bash "$VAULT" "$@" 2>&1) || _rc=$?
}

# Fresh test dirs for each test group
new_test_dirs() {
    _test_id=$((${_test_id:-0} + 1))
    _plain="${TESTDIR}/plain_${_test_id}"
    _cipher="${TESTDIR}/cipher_${_test_id}"
    mkdir -p "$_plain" "$_cipher"
    set_unmounted
}


# ═══════════════════════════════════════════════════════════════
#  status
# ═══════════════════════════════════════════════════════════════

section "status: not initialized"

new_test_dirs
run_vault --dir="$_plain" --cipher-dir="$_cipher" status
assert_eq "not initialized → exit 0" "0" "$_rc"
assert_contains "prints not initialized" "not initialized" "$_out"


section "status: locked"

new_test_dirs
touch "${_cipher}/gocryptfs.conf"
set_unmounted
run_vault --dir="$_plain" --cipher-dir="$_cipher" status
assert_eq "locked → exit 0" "0" "$_rc"
assert_contains "prints locked" "locked" "$_out"


section "status: open"

new_test_dirs
touch "${_cipher}/gocryptfs.conf"
set_mounted
run_vault --dir="$_plain" --cipher-dir="$_cipher" status
assert_eq "open → exit 0" "0" "$_rc"
assert_contains "prints open" "open" "$_out"


# ═══════════════════════════════════════════════════════════════
#  init
# ═══════════════════════════════════════════════════════════════

section "init: already initialized"

new_test_dirs
touch "${_cipher}/gocryptfs.conf"
run_vault --dir="$_plain" --cipher-dir="$_cipher" init
assert_eq "already initialized → exit 1" "1" "$_rc"
assert_contains "already initialized error" "already initialized" "$_out"


section "init: non-empty plain dir"

new_test_dirs
touch "${_plain}/existing-file"
run_vault --dir="$_plain" --cipher-dir="$_cipher" init
assert_eq "non-empty dir → exit 1" "1" "$_rc"
assert_contains "non-empty error" "not empty" "$_out"


section "init: successful (auto-generated passphrase)"

new_test_dirs
rm -rf "$_cipher"
run_vault_input "1
" --dir="$_plain" --cipher-dir="$_cipher" init
assert_eq "init → exit 0" "0" "$_rc"
assert_contains "init shows Initialized" "Initialized" "$_out"
assert_contains "init shows master key" "Your master key is:" "$_out"
if [[ -f "${_cipher}/gocryptfs.conf" ]]; then
    ok "gocryptfs.conf created"
else
    fail "gocryptfs.conf not created"
fi


section "init: successful (user passphrase)"

new_test_dirs
rm -rf "$_cipher"
run_vault_input "2
testpassphrase
testpassphrase
" --dir="$_plain" --cipher-dir="$_cipher" init
assert_eq "init user pass → exit 0" "0" "$_rc"
assert_contains "init user pass shows Initialized" "Initialized" "$_out"
assert_contains "init user pass shows master key" "Your master key is:" "$_out"


section "init: mismatched passphrase"

new_test_dirs
rm -rf "$_cipher"
run_vault_input "2
pass1
pass2
" --dir="$_plain" --cipher-dir="$_cipher" init
assert_eq "mismatch → exit 1" "1" "$_rc"
assert_contains "mismatch error" "do not match" "$_out"


# ═══════════════════════════════════════════════════════════════
#  open
# ═══════════════════════════════════════════════════════════════

section "open: not initialized → no-op"

new_test_dirs
set_unmounted
run_vault --dir="$_plain" --cipher-dir="$_cipher" open
assert_eq "not initialized → exit 0" "0" "$_rc"


section "open: already mounted → no-op"

new_test_dirs
touch "${_cipher}/gocryptfs.conf"
set_mounted
run_vault --dir="$_plain" --cipher-dir="$_cipher" open
assert_eq "already mounted → exit 0" "0" "$_rc"


section "open: successful mount"

new_test_dirs
touch "${_cipher}/gocryptfs.conf"
set_unmounted
run_vault --dir="$_plain" --cipher-dir="$_cipher" open
assert_eq "mount → exit 0" "0" "$_rc"
assert_not_contains "no error on mount" "failed" "$_out"


section "open: keyring lookup fails"

new_test_dirs
touch "${_cipher}/gocryptfs.conf"
set_unmounted

# Override secret-tool to fail on lookup
make_mock_in "${MOCK_BIN}" secret-tool '
case "$1" in
    store)  cat > /dev/null ;;
    lookup) exit 1 ;;
esac'

run_vault --dir="$_plain" --cipher-dir="$_cipher" open
assert_eq "keyring fail → exit 1" "1" "$_rc"
assert_contains "keyring error" "keyring lookup failed" "$_out"

# Restore mock
make_mock_in "${MOCK_BIN}" secret-tool '
case "$1" in
    store)  cat > /dev/null ;;
    lookup) echo "mock-passphrase" ;;
esac
exit 0'


# ═══════════════════════════════════════════════════════════════
#  close
# ═══════════════════════════════════════════════════════════════

section "close: not mounted → no-op"

new_test_dirs
set_unmounted
run_vault --dir="$_plain" --cipher-dir="$_cipher" close
assert_eq "not mounted → exit 0" "0" "$_rc"


section "close: successful unmount"

new_test_dirs
set_mounted
run_vault --dir="$_plain" --cipher-dir="$_cipher" close
assert_eq "unmount → exit 0" "0" "$_rc"


# ═══════════════════════════════════════════════════════════════
#  passwd
# ═══════════════════════════════════════════════════════════════

section "passwd: not initialized"

new_test_dirs
run_vault --dir="$_plain" --cipher-dir="$_cipher" passwd
assert_eq "passwd not initialized → exit 1" "1" "$_rc"
assert_contains "passwd not initialized error" "not initialized" "$_out"


section "passwd: successful rotation"

new_test_dirs
touch "${_cipher}/gocryptfs.conf"
run_vault_input "1
" --dir="$_plain" --cipher-dir="$_cipher" passwd
assert_eq "passwd → exit 0" "0" "$_rc"
assert_contains "passwd rotated" "rotated" "$_out"


summary
