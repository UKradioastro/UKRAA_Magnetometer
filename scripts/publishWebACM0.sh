#!/bin/bash

BASE_PATH=${MAGNETOMETER_BASE_PATH:-/home/pi/UKRAA_Magnetometer}
LOG_DIR="$BASE_PATH/logfiles"
MAIN_LOG="$LOG_DIR/log-MagnetometerACM0.txt"
ERROR_LOG="$LOG_DIR/log-error.txt"
SOURCE_DIR="$BASE_PATH/temp/rolling"
SOURCE_STATUS="$BASE_PATH/data/status/current.json"
DEST_ROLLING_DIR=/var/www/html/temp/rolling
DEST_STATUS_DIR=/var/www/html/status

log_msg() {
    printf '%s : %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1"
}

log_msg "publishWebACM0.sh       : Started publishing rolling web assets" >> "$MAIN_LOG"

if [ ! -f "$SOURCE_DIR/RollingXYZ.png" ] || [ ! -f "$SOURCE_DIR/RollingActivity.png" ]; then
  log_msg "publishWebACM0.sh       : FAILED - missing rolling plot assets" >> "$ERROR_LOG"
  exit 1
fi

if [ ! -f "$SOURCE_STATUS" ]; then
  log_msg "publishWebACM0.sh       : FAILED - missing status JSON" >> "$ERROR_LOG"
  exit 1
fi

mkdir -p "$DEST_ROLLING_DIR" "$DEST_STATUS_DIR"

if cp -a "$SOURCE_DIR/RollingXYZ.png" "$DEST_ROLLING_DIR/" >> "$ERROR_LOG" 2>&1; then
  log_msg "publishWebACM0.sh       : Copied RollingXYZ.png to $DEST_ROLLING_DIR" >> "$MAIN_LOG"
else
  log_msg "publishWebACM0.sh       : FAILED - could not copy RollingXYZ.png" >> "$ERROR_LOG"
  exit 1
fi

if cp -a "$SOURCE_DIR/RollingActivity.png" "$DEST_ROLLING_DIR/" >> "$ERROR_LOG" 2>&1; then
  log_msg "publishWebACM0.sh       : Copied RollingActivity.png to $DEST_ROLLING_DIR" >> "$MAIN_LOG"
else
  log_msg "publishWebACM0.sh       : FAILED - could not copy RollingActivity.png" >> "$ERROR_LOG"
  exit 1
fi

if cp -a "$SOURCE_STATUS" "$DEST_STATUS_DIR/current.json" >> "$ERROR_LOG" 2>&1; then
  log_msg "publishWebACM0.sh       : Copied current.json to $DEST_STATUS_DIR" >> "$MAIN_LOG"
else
  log_msg "publishWebACM0.sh       : FAILED - could not copy current.json" >> "$ERROR_LOG"
  exit 1
fi

log_msg "publishWebACM0.sh       : Completed publishing rolling web assets" >> "$MAIN_LOG"