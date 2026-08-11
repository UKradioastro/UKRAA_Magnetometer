#!/bin/bash

set -u

BASE_PATH=${MAGNETOMETER_BASE_PATH:-/home/pi/UKRAA_Magnetometer}
STATUS_FILE="$BASE_PATH/data/status/daily-health.txt"
MAIN_LOG="$BASE_PATH/logfiles/log-MagnetometerACM0.txt"
ERROR_LOG="$BASE_PATH/logfiles/log-error.txt"

extract_latest_line() {
    local file_path=$1
    local pattern=$2

    if [ ! -f "$file_path" ]; then
        echo "missing"
        return
    fi

    local line
    line=$(grep -E "$pattern" "$file_path" | tail -n 1)

    if [ -z "$line" ]; then
        echo "none"
        return
    fi

    echo "$line"
}

health_line="missing"
if [ -f "$STATUS_FILE" ]; then
    health_line=$(tail -n 1 "$STATUS_FILE")
fi

main_line=$(extract_latest_line "$MAIN_LOG" "Completed|FAILED|PASS|FAIL")
error_line=$(extract_latest_line "$ERROR_LOG" "FAILED|ERROR|FAIL")

printf '%s | HEALTH: %s | MAIN: %s | ERROR: %s\n' \
  "$(date '+%Y-%m-%d %H:%M:%S')" \
  "$health_line" \
  "$main_line" \
  "$error_line"
