#!/bin/bash

# script testHistoryProcessingACM0.sh to smoke test historical CSV assembly
# using synthetic hourly data in a temporary sandbox base path.

set -u

BASE_PATH=${MAGNETOMETER_BASE_PATH:-/home/pi/UKRAA_Magnetometer}
HISTORY_SCRIPT="$BASE_PATH/scripts/ProcessHistoryACM0.py"

fail() {
    printf 'FAIL: %s\n' "$1"
    exit 1
}

if [ ! -f "$HISTORY_SCRIPT" ]; then
    fail "Missing history processor: $HISTORY_SCRIPT"
fi

TEST_ROOT=$(mktemp -d)
cleanup() {
    rm -rf "$TEST_ROOT"
}
trap cleanup EXIT

# two consecutive days of synthetic hourly data
mkdir -p "$TEST_ROOT/data/processed/hour/2026/2026-08"

cat > "$TEST_ROOT/data/processed/hour/2026/2026-08/2026-08-01.csv" <<'CSV'
2026-08-01 00:30:00,1.0,1.0,1.0,100,200,300,20.0,5.0,224,63.4,300,374,53.1,detector
2026-08-01 01:30:00,1.0,1.0,1.0,101,201,301,20.1,5.0,225,63.3,301,376,53.0,detector
CSV

cat > "$TEST_ROOT/data/processed/hour/2026/2026-08/2026-08-02.csv" <<'CSV'
2026-08-02 00:30:00,1.0,1.0,1.0,102,202,302,20.2,5.0,226,63.2,302,378,52.9,detector
2026-08-02 01:30:00,1.0,1.0,1.0,103,203,303,20.3,5.0,227,63.1,303,380,52.8,detector
CSV

if ! MAGNETOMETER_BASE_PATH="$TEST_ROOT" MAGNETOMETER_TARGET_DATE="2026-08-02" \
     python3 "$HISTORY_SCRIPT" --window 7d; then
    fail "ProcessHistoryACM0.py exited non-zero"
fi

HISTORY_FILE="$TEST_ROOT/data/history/7d/history.csv"

if [ ! -f "$HISTORY_FILE" ]; then
    fail "missing history CSV: $HISTORY_FILE"
fi

ROW_COUNT=$(wc -l < "$HISTORY_FILE")
if [ "$ROW_COUNT" -ne 4 ]; then
    fail "expected 4 rows in history CSV, got $ROW_COUNT"
fi

if ! head -n 1 "$HISTORY_FILE" | grep -q '^2026-08-01 00:30:00'; then
    fail "history CSV not sorted oldest-first"
fi

echo "PASS: historical CSV generation"
