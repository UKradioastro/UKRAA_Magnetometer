#!/bin/bash

set -u

# The installer deletes its own directory, so a leftover cwd can break child shells.
cd / || exit 1

BASE_PATH=${MAGNETOMETER_BASE_PATH:-/home/pi/UKRAA_Magnetometer}

run_check() {
    local label=$1
    local script_path=$2

    printf 'Running: %s\n' "$label"

    if /bin/bash "$script_path"; then
        printf 'PASS: %s\n' "$label"
        return 0
    fi

    printf 'FAIL: %s\n' "$label"
    return 1
}

if [ "${1:-}" = "--help" ]; then
    echo "Usage: $0"
    echo "  Runs post-update validation checks for optional daily plots."
    exit 0
fi

failures=0

if ! run_check "Optional daily publish logic" "$BASE_PATH/scripts/testOptionalDailyPlotsACM0.sh"; then
    failures=$((failures + 1))
fi

if ! run_check "Web optional visibility logic" "$BASE_PATH/scripts/testWebOptionalPlotsVisibilityACM0.sh"; then
    failures=$((failures + 1))
fi

if [ "$failures" -eq 0 ]; then
    echo "POST_UPDATE_CHECKS: PASS"
    exit 0
fi

echo "POST_UPDATE_CHECKS: FAIL ($failures failing check(s))"
exit 1
