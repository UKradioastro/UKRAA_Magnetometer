#!/bin/bash

set -u

BASE_PATH=${MAGNETOMETER_BASE_PATH:-/home/pi/UKRAA_Magnetometer}
WEB_ROOT=${MAGNETOMETER_WEB_ROOT:-/var/www/html}
STATUS_DIR="$BASE_PATH/data/status"
MARKER_FILE="$STATUS_DIR/daily-health.txt"

mkdir -p "$STATUS_DIR"

YESTERDAY=$(date -d yesterday +%Y-%m-%d)
MINUTE_FILE="$BASE_PATH/data/minute/$(date -d yesterday +%Y)/$(date -d yesterday +%Y-%m)/$YESTERDAY.csv"
RAW_FILE="$BASE_PATH/data/raw/$(date -d yesterday +%Y)/$(date -d yesterday +%Y-%m)/$YESTERDAY.csv"
WEB_TEMP_DIR="$WEB_ROOT/temp/yesterday"

# No raw data for that date means there was nothing to process, not a pipeline fault
# (fresh install, or the acquisition service was stopped all day).
if [ ! -f "$RAW_FILE" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') : DAILY_HEALTH: PENDING : date=$YESTERDAY : no raw data recorded for that date: $RAW_FILE" > "$MARKER_FILE"
    exit 0
fi

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
if [ ! -f "$MINUTE_FILE" ]; then
    status="FAIL"
    append_issue "missing minute data file: $MINUTE_FILE"
fi

# Required daily web files check.
for required_file in Activity.png XYZ.png; do
    if [ ! -f "$WEB_TEMP_DIR/$required_file" ]; then
        status="FAIL"
        append_issue "missing web daily file: $WEB_TEMP_DIR/$required_file"
    fi
done

# Optional daily web files are only required when enabled.
PLOT_OPTIONS_SCRIPT="$BASE_PATH/scripts/GetPlotOptionsACM0.py"

if [ ! -f "$PLOT_OPTIONS_SCRIPT" ]; then
    status="FAIL"
    append_issue "missing plot options script: $PLOT_OPTIONS_SCRIPT"
elif ! plot_options=$(/usr/bin/python3 "$PLOT_OPTIONS_SCRIPT" 2>&1); then
    status="FAIL"
    append_issue "could not read plot options: $plot_options"
else
    read -r plot_hdz plot_bi plot_noaa noaa_hemisphere <<< "$plot_options"

    if [ -z "${plot_hdz:-}" ] || [ -z "${plot_bi:-}" ] || [ -z "${plot_noaa:-}" ] || [ -z "${noaa_hemisphere:-}" ]; then
        status="FAIL"
        append_issue "unexpected plot options output: '$plot_options'"
    fi

    if [ "${plot_hdz:-}" = "true" ]; then
        if [ ! -f "$WEB_TEMP_DIR/HDZ.png" ]; then
            status="FAIL"
            append_issue "missing web HDZ file while plot_hdz=true: $WEB_TEMP_DIR/HDZ.png"
        fi
    fi

    if [ "${plot_bi:-}" = "true" ]; then
        if [ ! -f "$WEB_TEMP_DIR/BI.png" ]; then
            status="FAIL"
            append_issue "missing web BI file while plot_bi=true: $WEB_TEMP_DIR/BI.png"
        fi
    fi
fi

# Mature, enabled period plots are required only after their complete-day
# threshold has been reached; younger periods intentionally show a placeholder.
PERIOD_STATUS_FILE="$STATUS_DIR/period-plots.json"
if [ ! -f "$PERIOD_STATUS_FILE" ]; then
    status="FAIL"
    append_issue "missing period plot availability: $PERIOD_STATUS_FILE"
elif ! period_requirements=$(/usr/bin/python3 - "$PERIOD_STATUS_FILE" <<'PY'
import json
import sys

with open(sys.argv[1], encoding='UTF-8') as status_file:
    status = json.load(status_file)

for period_name, period in status['periods'].items():
    if not (period['enabled'] and period['available']):
        continue
    for family_name, family_enabled in status['families'].items():
        if family_enabled:
            print(period_name, family_name.upper())
PY
); then
    status="FAIL"
    append_issue "could not read period plot availability: $period_requirements"
else
    while read -r period_name family_name; do
        [ -n "${period_name:-}" ] || continue
        period_file="$WEB_ROOT/temp/periods/$period_name/$family_name.png"
        if [ ! -f "$period_file" ]; then
            status="FAIL"
            append_issue "missing mature period plot: $period_file"
        fi
    done <<< "$period_requirements"
fi

# Write a short marker line that can be monitored externally.
if [ "$status" = "PASS" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') : DAILY_HEALTH: PASS : date=$YESTERDAY" > "$MARKER_FILE"
    exit 0
fi

echo "$(date '+%Y-%m-%d %H:%M:%S') : DAILY_HEALTH: FAIL : date=$YESTERDAY : $issues" > "$MARKER_FILE"
exit 1
