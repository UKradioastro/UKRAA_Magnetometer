#!/bin/bash

set -u

BASE_PATH=${MAGNETOMETER_BASE_PATH:-/home/pi/UKRAA_Magnetometer}
LOG_DIR="$BASE_PATH/logfiles"
MAIN_LOG="$LOG_DIR/log-MagnetometerACM0.txt"
ERROR_LOG="$LOG_DIR/log-error.txt"

log_msg() {
    printf '%s : %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1"
}

usage() {
    echo "Usage: $0 YYYY-MM-DD [--archive]"
    echo "  YYYY-MM-DD  target UTC date to regenerate"
    echo "  --archive   also write plots/Activity/YYYY/YYYY-MM/YYYY-MM-DD.png (default is temp only)"
}

TARGET_DATE=${1:-}
ARCHIVE_MODE=0

if [ -z "$TARGET_DATE" ]; then
    usage
    exit 1
fi

if [ "${2:-}" = "--archive" ]; then
    ARCHIVE_MODE=1
fi

if ! date -d "$TARGET_DATE" '+%Y-%m-%d' >/dev/null 2>&1; then
    echo "Invalid date: $TARGET_DATE"
    usage
    exit 1
fi

log_msg "testActivityPlotACM0.sh   : Regenerating Activity plot for $TARGET_DATE (archive=$ARCHIVE_MODE)" >> "$MAIN_LOG"

if MAGNETOMETER_BASE_PATH="$BASE_PATH" MAGNETOMETER_TARGET_DATE="$TARGET_DATE" su pi -c "/usr/bin/python3 $BASE_PATH/scripts/ProcessDataHourACM0.py >> $MAIN_LOG 2>> $ERROR_LOG"; then
    log_msg "testActivityPlotACM0.sh   : Completed hourly processing for $TARGET_DATE" >> "$MAIN_LOG"
else
    log_msg "testActivityPlotACM0.sh   : FAILED hourly processing for $TARGET_DATE" >> "$ERROR_LOG"
    exit 1
fi

if MAGNETOMETER_BASE_PATH="$BASE_PATH" MAGNETOMETER_TARGET_DATE="$TARGET_DATE" MAGNETOMETER_ACTIVITY_PLOT_ARCHIVE="$ARCHIVE_MODE" su pi -c "/usr/bin/gnuplot $BASE_PATH/scripts/PlotDataActivityACM0.gp >> $MAIN_LOG 2>> $ERROR_LOG"; then
    log_msg "testActivityPlotACM0.sh   : Completed Activity plot for $TARGET_DATE" >> "$MAIN_LOG"
else
    log_msg "testActivityPlotACM0.sh   : FAILED Activity plot for $TARGET_DATE" >> "$ERROR_LOG"
    exit 1
fi

echo "Done: $BASE_PATH/temp/Activity.png"
if [ "$ARCHIVE_MODE" -eq 1 ]; then
    echo "Archive: $BASE_PATH/plots/Activity/$(date -d "$TARGET_DATE" +%Y)/$(date -d "$TARGET_DATE" +%Y-%m)/$TARGET_DATE.png"
fi
