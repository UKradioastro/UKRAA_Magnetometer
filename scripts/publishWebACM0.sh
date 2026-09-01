#!/bin/bash

BASE_PATH=${MAGNETOMETER_BASE_PATH:-/home/pi/UKRAA_Magnetometer}
LOG_DIR="$BASE_PATH/logfiles"
MAIN_LOG="$LOG_DIR/log-MagnetometerACM0.txt"
ERROR_LOG="$LOG_DIR/log-error.txt"
SOURCE_DIR="$BASE_PATH/temp/rolling"
SOURCE_STATUS="$BASE_PATH/data/status/current.json"
SOURCE_NOAA="$BASE_PATH/temp/noaa/latest.jpg"
DEST_ROLLING_DIR=/var/www/html/temp/rolling
DEST_STATUS_DIR=/var/www/html/status
DEST_NOAA_DIR=/var/www/html/temp/noaa

log_msg() {
    printf '%s : %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1"
}

log_msg "publishWebACM0.sh         : Started publishing rolling web assets" >> "$MAIN_LOG"

if [ ! -f "$SOURCE_DIR/RollingXYZ.png" ] || [ ! -f "$SOURCE_DIR/RollingActivity.png" ]; then
  log_msg "publishWebACM0.sh         : FAILED - missing rolling plot assets" >> "$ERROR_LOG"
  exit 1
fi

if [ ! -f "$SOURCE_STATUS" ]; then
  log_msg "publishWebACM0.sh         : FAILED - missing status JSON" >> "$ERROR_LOG"
  exit 1
fi

# read HDZ and BI plot flags from plot.ini (defaults: true true)
if ! PLOT_OPTIONS=$(MAGNETOMETER_BASE_PATH="$BASE_PATH" /usr/bin/python3 "$BASE_PATH/scripts/GetPlotOptionsACM0.py" 2>&1); then
  log_msg "publishWebACM0.sh         : FAILED to read plot options: $PLOT_OPTIONS" >> "$ERROR_LOG"
  exit 1
fi

read -r PLOT_HDZ PLOT_BI <<< "$PLOT_OPTIONS"

if [ -z "${PLOT_HDZ:-}" ] || [ -z "${PLOT_BI:-}" ]; then
  log_msg "publishWebACM0.sh         : FAILED - unexpected plot options output: '$PLOT_OPTIONS'" >> "$ERROR_LOG"
  exit 1
fi

if [ "$PLOT_HDZ" = "true" ] && [ ! -f "$SOURCE_DIR/RollingHDZ.png" ]; then
  log_msg "publishWebACM0.sh         : FAILED - missing RollingHDZ.png while plot_hdz=true" >> "$ERROR_LOG"
  exit 1
fi

if [ "$PLOT_BI" = "true" ] && [ ! -f "$SOURCE_DIR/RollingBI.png" ]; then
  log_msg "publishWebACM0.sh         : FAILED - missing RollingBI.png while plot_bi=true" >> "$ERROR_LOG"
  exit 1
fi

mkdir -p "$DEST_ROLLING_DIR" "$DEST_STATUS_DIR" "$DEST_NOAA_DIR"

if cp -a "$SOURCE_DIR/RollingXYZ.png" "$DEST_ROLLING_DIR/" >> "$ERROR_LOG" 2>&1; then
  log_msg "publishWebACM0.sh         : Copied RollingXYZ.png to $DEST_ROLLING_DIR" >> "$MAIN_LOG"
else
  log_msg "publishWebACM0.sh         : FAILED - could not copy RollingXYZ.png" >> "$ERROR_LOG"
  exit 1
fi

if cp -a "$SOURCE_DIR/RollingActivity.png" "$DEST_ROLLING_DIR/" >> "$ERROR_LOG" 2>&1; then
  log_msg "publishWebACM0.sh         : Copied RollingActivity.png to $DEST_ROLLING_DIR" >> "$MAIN_LOG"
else
  log_msg "publishWebACM0.sh         : FAILED - could not copy RollingActivity.png" >> "$ERROR_LOG"
  exit 1
fi

if [ "$PLOT_HDZ" = "true" ]; then
  if cp -a "$SOURCE_DIR/RollingHDZ.png" "$DEST_ROLLING_DIR/" >> "$ERROR_LOG" 2>&1; then
    log_msg "publishWebACM0.sh         : Copied RollingHDZ.png to $DEST_ROLLING_DIR" >> "$MAIN_LOG"
  else
    log_msg "publishWebACM0.sh         : FAILED - could not copy RollingHDZ.png" >> "$ERROR_LOG"
    exit 1
  fi
elif [ -f "$DEST_ROLLING_DIR/RollingHDZ.png" ]; then
  rm -f "$DEST_ROLLING_DIR/RollingHDZ.png"
  log_msg "publishWebACM0.sh         : Removed stale RollingHDZ.png (plot_hdz=false)" >> "$MAIN_LOG"
else
  log_msg "publishWebACM0.sh         : Rolling HDZ not required (plot_hdz=false)" >> "$MAIN_LOG"
fi

if [ "$PLOT_BI" = "true" ]; then
  if cp -a "$SOURCE_DIR/RollingBI.png" "$DEST_ROLLING_DIR/" >> "$ERROR_LOG" 2>&1; then
    log_msg "publishWebACM0.sh         : Copied RollingBI.png to $DEST_ROLLING_DIR" >> "$MAIN_LOG"
  else
    log_msg "publishWebACM0.sh         : FAILED - could not copy RollingBI.png" >> "$ERROR_LOG"
    exit 1
  fi
elif [ -f "$DEST_ROLLING_DIR/RollingBI.png" ]; then
  rm -f "$DEST_ROLLING_DIR/RollingBI.png"
  log_msg "publishWebACM0.sh         : Removed stale RollingBI.png (plot_bi=false)" >> "$MAIN_LOG"
else
  log_msg "publishWebACM0.sh         : Rolling BI not required (plot_bi=false)" >> "$MAIN_LOG"
fi

if cp -a "$SOURCE_STATUS" "$DEST_STATUS_DIR/current.json" >> "$ERROR_LOG" 2>&1; then
  log_msg "publishWebACM0.sh         : Copied current.json to $DEST_STATUS_DIR" >> "$MAIN_LOG"
else
  log_msg "publishWebACM0.sh         : FAILED - could not copy current.json" >> "$ERROR_LOG"
  exit 1
fi

if [ -f "$SOURCE_NOAA" ]; then
  if cp -a "$SOURCE_NOAA" "$DEST_NOAA_DIR/latest.jpg" >> "$ERROR_LOG" 2>&1; then
    chmod 644 "$DEST_NOAA_DIR/latest.jpg"
    log_msg "publishWebACM0.sh         : Copied NOAA aurora forecast to $DEST_NOAA_DIR" >> "$MAIN_LOG"
  else
    log_msg "publishWebACM0.sh         : WARNING - could not copy NOAA aurora forecast" >> "$ERROR_LOG"
  fi
else
  log_msg "publishWebACM0.sh         : NOAA aurora forecast not present, skipping" >> "$MAIN_LOG"
fi

log_msg "publishWebACM0.sh         : Completed publishing rolling web assets" >> "$MAIN_LOG"
