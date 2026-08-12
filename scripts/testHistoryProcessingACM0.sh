#!/bin/bash

set -u

BASE_PATH=${MAGNETOMETER_BASE_PATH:-/home/pi/UKRAA_Magnetometer}
HISTORY_SCRIPT="$BASE_PATH/scripts/ProcessHistoryACM0.py"

if [ ! -f "$HISTORY_SCRIPT" ]; then
    echo "FAIL: Missing history processor: $HISTORY_SCRIPT"
    exit 1
fi

TMPDIR=$(mktemp -d)
cleanup() {
    rm -rf "$TMPDIR"
}
trap cleanup EXIT

mkdir -p "$TMPDIR/data/processed/hour/2026/2026-08" "$TMPDIR/data/history"
cat > "$TMPDIR/data/processed/hour/2026/2026-08/2026-08-01.csv" <<'CSV'
2026-08-01 00:00:00,0,0,0,100,200,300,20,1,0,0,300,0,0,detector
2026-08-01 01:00:00,0,0,0,100,200,300,20,2,0,0,300,0,0,detector
2026-08-01 02:00:00,0,0,0,100,200,300,20,3,0,0,300,0,0,detector
CSV

cat > "$TMPDIR/data/processed/hour/2026/2026-08/2026-08-02.csv" <<'CSV'
2026-08-02 00:00:00,0,0,0,100,200,300,20,4,0,0,300,0,0,detector
2026-08-02 01:00:00,0,0,0,100,200,300,20,5,0,0,300,0,0,detector
CSV

MAGNETOMETER_BASE_PATH="$TMPDIR" MAGNETOMETER_TARGET_DATE="2026-08-02" python3 "$HISTORY_SCRIPT"

if [ ! -f "$TMPDIR/data/history/7d/history.csv" ]; then
    echo "FAIL: missing 7d history CSV"
    exit 1
fi

if [ ! -s "$TMPDIR/data/history/7d/history.csv" ]; then
    echo "FAIL: empty 7d history CSV"
    exit 1
fi

echo "PASS: historical CSV generation"
