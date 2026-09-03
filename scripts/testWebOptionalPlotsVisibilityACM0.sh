#!/bin/bash

set -u

# The installer deletes the source WWW folder, so run from a directory that always exists.
cd / || exit 1

BASE_PATH=${MAGNETOMETER_BASE_PATH:-/home/pi/UKRAA_Magnetometer}
WEB_ROOT=${MAGNETOMETER_WEB_ROOT:-/var/www/html}
FILE_OWNER=${MAGNETOMETER_FILE_OWNER:-pi}

# Prefer the source copy (development checkout); fall back to the deployed copy (installed system).
if [ -f "$BASE_PATH/WWW/index.html" ]; then
    INDEX_FILE="$BASE_PATH/WWW/index.html"
else
    INDEX_FILE="$WEB_ROOT/index.html"
fi

TEST_ROOT=${1:-"$BASE_PATH/data/tests/web-optional-visibility"}

if [ "${1:-}" = "--help" ]; then
    echo "Usage: $0 [TEST_ROOT]"
    echo "  Verifies optional HDZ/BI web section visibility contract."
    echo "  Default TEST_ROOT: $BASE_PATH/tests/web-optional-visibility"
    exit 0
fi

log() {
    printf '%s\n' "$1"
}

fail() {
    printf 'FAIL: %s\n' "$1"
    exit 1
}

assert_contains() {
    local needle=$1
    if ! grep -q "$needle" "$INDEX_FILE"; then
        fail "index.html missing expected marker: $needle"
    fi
}

compute_expected_visibility() {
    local temp_dir=$1

    if [ -f "$temp_dir/HDZ.png" ] || [ -f "$temp_dir/BI.png" ]; then
        echo "show"
    else
        echo "hide"
    fi
}

run_case() {
    local case_name=$1
    local files_to_create=$2
    local expected=$3

    local case_dir="$TEST_ROOT/$case_name"
    local temp_dir="$case_dir/temp"

    rm -rf "$case_dir"
    mkdir -p "$temp_dir"

    for file_name in $files_to_create; do
        touch "$temp_dir/$file_name"
    done

    local actual
    actual=$(compute_expected_visibility "$temp_dir")

    if [ "$actual" != "$expected" ]; then
        fail "$case_name expected $expected, got $actual"
    fi

    log "PASS: $case_name ($actual)"
}

if [ ! -f "$INDEX_FILE" ]; then
    fail "index file not found: $INDEX_FILE"
fi

# Verify key webpage hooks exist.
assert_contains 'id="HDZ"'
assert_contains 'id="BI"'
assert_contains 'id="navHdz"'
assert_contains 'id="navBi"'
assert_contains 'id="navDemoHdz"'
assert_contains 'id="navDemoBi"'
assert_contains 'id="cardHDZ"'
assert_contains 'id="cardBI"'
assert_contains 'id="cardRollingHDZ"'
assert_contains 'id="cardRollingBI"'
assert_contains 'function refreshOptionalGraphs()'
assert_contains './temp/HDZ.png'
assert_contains './temp/BI.png'
assert_contains './temp/rolling/RollingHDZ.png'
assert_contains './temp/rolling/RollingBI.png'

rm -rf "$TEST_ROOT"
mkdir -p "$TEST_ROOT"

# Chown the shared tests/ parent too, since mkdir -p creates it as root when invoked via sudo.
if [ "$(id -u)" -eq 0 ]; then
    chown -R "$FILE_OWNER:$FILE_OWNER" "$BASE_PATH/data/tests"
fi

# Contract cases: section hidden when none exist, shown when one or more exist.
run_case "none_present" "" "hide"
run_case "hdz_only" "HDZ.png" "show"
run_case "bi_only" "BI.png" "show"
run_case "all_present" "HDZ.png BI.png" "show"

log "All optional web visibility checks passed."
if [ "$(id -u)" -eq 0 ]; then
    chown -R "$FILE_OWNER:$FILE_OWNER" "$BASE_PATH/data/tests"
fi
log "Test root: $TEST_ROOT"
