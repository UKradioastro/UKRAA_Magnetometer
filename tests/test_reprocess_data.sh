#!/bin/bash

set -euo pipefail

SCRIPT_PATH=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../scripts" && pwd)/reprocessData.sh
TEST_BASE=$(mktemp -d)
trap 'rm -rf "$TEST_BASE"' EXIT

fail() {
    echo "REPROCESS_DATA: FAIL - $1"
    exit 1
}

make_raw() {
    local day=$1
    mkdir -p "$TEST_BASE/data/raw/${day:0:4}/${day:0:7}"
    : > "$TEST_BASE/data/raw/${day:0:4}/${day:0:7}/$day.csv"
}

run_reprocess() {
    MAGNETOMETER_BASE_PATH="$TEST_BASE" MAGNETOMETER_FILE_OWNER="$(id -un)" \
        /bin/bash "$SCRIPT_PATH" "$@"
}

mkdir -p "$TEST_BASE/logfiles"
make_raw 2026-01-15
make_raw 2026-02-01
make_raw 2026-02-28
make_raw "$(date +%Y-%m-%d)"
mkdir -p "$TEST_BASE/data/raw/2026/2026-02"
: > "$TEST_BASE/data/raw/2026/2026-02/notes.csv"

output=$(run_reprocess --dry-run)
expected=$(printf '%s\n' \
    'Days to reprocess: 3 (2026-01-15 to 2026-02-28)' \
    2026-01-15 2026-02-01 2026-02-28)
[ "$output" = "$expected" ] || fail "default range excludes today and non-date files, got: $output"

output=$(run_reprocess --dry-run --from 2026-02-01 --to 2026-02-27)
expected=$(printf '%s\n' 'Days to reprocess: 1 (2026-02-01 to 2026-02-01)' 2026-02-01)
[ "$output" = "$expected" ] || fail "--from/--to filtering, got: $output"

if run_reprocess --dry-run --from 2026-13-01 > /dev/null 2>&1; then
    fail "invalid --from date accepted"
fi

if run_reprocess --dry-run --from 2026-03-01 --to 2026-02-01 > /dev/null 2>&1; then
    fail "--from after --to accepted"
fi

if run_reprocess --dry-run --from 2025-01-01 --to 2025-12-31 > /dev/null 2>&1; then
    fail "empty range should exit non-zero"
fi

if run_reprocess --bogus > /dev/null 2>&1; then
    fail "unknown option accepted"
fi

echo 'REPROCESS_DATA: PASS'
