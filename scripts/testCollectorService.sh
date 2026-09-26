#!/bin/bash

set -u

SYSTEMCTL=${MAGNETOMETER_SYSTEMCTL:-systemctl}
UNIT_DIRECTORY=${MAGNETOMETER_SYSTEMD_UNIT_DIR:-/etc/systemd/system}
NEW_UNIT=PicoMagnetometer.service
OLD_UNIT=PicoMagnetometerACM0.service
failures=0

if ! "$SYSTEMCTL" is-enabled --quiet "$NEW_UNIT"; then
    echo "FAIL: $NEW_UNIT is not enabled"
    failures=$((failures + 1))
fi

if ! "$SYSTEMCTL" is-active --quiet "$NEW_UNIT"; then
    echo "FAIL: $NEW_UNIT is not active"
    failures=$((failures + 1))
fi

if "$SYSTEMCTL" is-active --quiet "$OLD_UNIT"; then
    echo "FAIL: legacy $OLD_UNIT is still active"
    failures=$((failures + 1))
fi

if [ -e "$UNIT_DIRECTORY/$OLD_UNIT" ]; then
    echo "FAIL: legacy unit file remains at $UNIT_DIRECTORY/$OLD_UNIT"
    failures=$((failures + 1))
fi

if [ "$failures" -ne 0 ]; then
    exit 1
fi

echo "COLLECTOR_SERVICE: PASS ($NEW_UNIT enabled and active; legacy unit retired)"