#!/bin/bash

set -u

BASE_PATH=${MAGNETOMETER_BASE_PATH:-/home/pi/UKRAA_Magnetometer}
ERROR_LOG="$BASE_PATH/logfiles/log-error.txt"

mkdir -p "$BASE_PATH/logfiles"

if [ "$#" -eq 0 ]; then
    printf '%s : runCronJob.sh       : FAILED - command is required\n' "$(date '+%Y-%m-%d %H:%M:%S')" >> "$ERROR_LOG"
    exit 2
fi

STDERR_FILE=$(mktemp)
trap 'rm -f "$STDERR_FILE"' EXIT

"$@" 2> "$STDERR_FILE"
EXIT_CODE=$?
COMMAND_NAME=$(basename "${2:-$1}")

while IFS= read -r line; do
    if [ -n "$line" ]; then
        printf '%s : %-27s : %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$COMMAND_NAME stderr" "$line" >> "$ERROR_LOG"
    fi
done < "$STDERR_FILE"

exit "$EXIT_CODE"