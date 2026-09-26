#!/bin/bash

set -u

source "$(dirname "${BASH_SOURCE[0]}")/magnetometer-env.sh"

# The installer deletes its own directory, so a leftover cwd can break child shells.
cd / || exit 1

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

if ! run_check "Optional daily publish logic" "$BASE_PATH/scripts/testOptionalDailyPlots.sh"; then
    failures=$((failures + 1))
fi

if ! run_check "Web optional visibility logic" "$BASE_PATH/scripts/testWebOptionalPlotsVisibility.sh"; then
    failures=$((failures + 1))
fi

if ! run_check "Collector service migration" "$BASE_PATH/scripts/testCollectorService.sh"; then
    failures=$((failures + 1))
fi

if [ "$failures" -eq 0 ]; then
    echo "POST_UPDATE_CHECKS: PASS"
    exit 0
fi

echo "POST_UPDATE_CHECKS: FAIL ($failures failing check(s))"
exit 1
