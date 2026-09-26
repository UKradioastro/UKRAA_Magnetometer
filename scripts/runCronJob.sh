#!/bin/bash

set -u

source "$(dirname "${BASH_SOURCE[0]}")/magnetometer-env.sh"
ERROR_LOG="$BASE_PATH/logfiles/log-error.txt"

mkdir -p "$BASE_PATH/logfiles"

if [ "$#" -eq 0 ]; then
    printf '%s : %-34s : FAILED - command is required\n' "$(date '+%Y-%m-%d %H:%M:%S')" 'runCronJob.sh' >> "$ERROR_LOG"
    exit 2
fi

STDERR_FILE=$(mktemp)
trap 'rm -f "$STDERR_FILE"' EXIT

"$@" 2> "$STDERR_FILE"
EXIT_CODE=$?
COMMAND_NAME=$(basename "${2:-$1}")

while IFS= read -r line; do
    if [ -n "$line" ]; then
        printf '%s : %-34s : %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$COMMAND_NAME stderr" "$line" >> "$ERROR_LOG"
    fi
done < "$STDERR_FILE"

exit "$EXIT_CODE"