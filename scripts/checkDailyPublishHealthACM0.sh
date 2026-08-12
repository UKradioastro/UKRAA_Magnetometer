#!/bin/bash

set -u

BASE_PATH=${MAGNETOMETER_BASE_PATH:-/home/pi/UKRAA_Magnetometer}
WEB_ROOT=${MAGNETOMETER_WEB_ROOT:-/var/www/html}
STATUS_DIR="$BASE_PATH/data/status"
MARKER_FILE="$STATUS_DIR/daily-health.txt"

mkdir -p "$STATUS_DIR"

YESTERDAY=$(date -d yesterday +%Y-%m-%d)
PROCESSED_FILE="$BASE_PATH/data/processed/$(date -d yesterday +%Y)/$(date -d yesterday +%Y-%m)/$YESTERDAY.csv"
WEB_TEMP_DIR="$WEB_ROOT/temp"

status="PASS"
issues=""

append_issue() {
    local msg=$1
    if [ -n "$issues" ]; then
        issues="$issues; $msg"
    else
        issues="$msg"
    fi
}

# Daily processing output check.
if [ ! -f "$PROCESSED_FILE" ]; then
    status="FAIL"
    append_issue "missing processed day file: $PROCESSED_FILE"
fi

# Required daily web files check.
for required_file in Activity.png XYZ.png; do
    if [ ! -f "$WEB_TEMP_DIR/$required_file" ]; then
        status="FAIL"
        append_issue "missing web daily file: $WEB_TEMP_DIR/$required_file"
    fi
done

# Optional daily web files are only required when enabled.
if [ -x "$BASE_PATH/scripts/GetPlotOptionsACM0.py" ]; then
    read -r plot_hdz plot_bi < <(/usr/bin/python3 "$BASE_PATH/scripts/GetPlotOptionsACM0.py")

    if [ "$plot_hdz" = "true" ]; then
        if [ ! -f "$WEB_TEMP_DIR/HDZ.png" ]; then
            status="FAIL"
            append_issue "missing web HDZ file while plot_hdz=true: $WEB_TEMP_DIR/HDZ.png"
        fi
    fi

    if [ "$plot_bi" = "true" ]; then
        if [ ! -f "$WEB_TEMP_DIR/BI.png" ]; then
            status="FAIL"
            append_issue "missing web BI file while plot_bi=true: $WEB_TEMP_DIR/BI.png"
        fi
    fi
fi

# Write a short marker line that can be monitored externally.
if [ "$status" = "PASS" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') : DAILY_HEALTH: PASS : date=$YESTERDAY" > "$MARKER_FILE"
    exit 0
fi

echo "$(date '+%Y-%m-%d %H:%M:%S') : DAILY_HEALTH: FAIL : date=$YESTERDAY : $issues" > "$MARKER_FILE"
exit 1
