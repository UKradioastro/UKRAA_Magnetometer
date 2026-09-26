#!/bin/bash

source "$(dirname "${BASH_SOURCE[0]}")/magnetometer-env.sh"
LOG_DIR="$BASE_PATH/logfiles"
MAIN_LOG="$LOG_DIR/log-Magnetometer.txt"
ERROR_LOG="$LOG_DIR/log-error.txt"
SOURCE_DIR="$BASE_PATH/temp/rolling"
SOURCE_STATUS="$BASE_PATH/data/status/current.json"
SOURCE_PLOT_OPTIONS="$BASE_PATH/data/status/plot-options.json"
SOURCE_NOAA="$BASE_PATH/temp/noaa/latest.jpg"
SOURCE_KP="$BASE_PATH/temp/kp/PlanetaryKp.png"
DEST_ROLLING_DIR=/var/www/html/temp/rolling
DEST_STATUS_DIR=/var/www/html/status
DEST_NOAA_DIR=/var/www/html/temp/noaa
DEST_KP_DIR=/var/www/html/temp/kp

source "$(dirname "${BASH_SOURCE[0]}")/logging.sh"

log_msg() {
    write_log_entry "$1"
}

log_msg "publishWeb.sh         : Started publishing rolling web assets" >> "$MAIN_LOG"

if [ ! -f "$SOURCE_DIR/RollingXYZ.png" ] || [ ! -f "$SOURCE_DIR/RollingActivity.png" ]; then
  log_msg "publishWeb.sh         : FAILED - missing rolling plot assets" >> "$ERROR_LOG"
  exit 1
fi

if [ ! -f "$SOURCE_STATUS" ]; then
  log_msg "publishWeb.sh         : FAILED - missing status JSON" >> "$ERROR_LOG"
  exit 1
fi

# read HDZ and BI plot flags from plot.ini (defaults: true true)
if ! PLOT_OPTIONS=$(MAGNETOMETER_BASE_PATH="$BASE_PATH" /usr/bin/python3 "$BASE_PATH/scripts/GetPlotOptions.py" 2>&1); then
  log_msg "publishWeb.sh         : FAILED to read plot options: $PLOT_OPTIONS" >> "$ERROR_LOG"
  exit 1
fi

read -r PLOT_HDZ PLOT_BI PLOT_NOAA NOAA_HEMISPHERE <<< "$PLOT_OPTIONS"

if ! PLOT_KP=$(MAGNETOMETER_BASE_PATH="$BASE_PATH" /usr/bin/python3 "$BASE_PATH/scripts/GetKpOptions.py" 2>&1); then
  log_msg "publishWeb.sh         : FAILED to read Kp plot option: $PLOT_KP" >> "$ERROR_LOG"
  exit 1
fi

if [ -z "${PLOT_HDZ:-}" ] || [ -z "${PLOT_BI:-}" ] || [ -z "${PLOT_NOAA:-}" ] || [ -z "${NOAA_HEMISPHERE:-}" ] || { [ "$PLOT_KP" != "true" ] && [ "$PLOT_KP" != "false" ]; }; then
  log_msg "publishWeb.sh         : FAILED - unexpected plot options output: '$PLOT_OPTIONS'" >> "$ERROR_LOG"
  exit 1
fi

if [ "$PLOT_HDZ" = "true" ] && [ ! -f "$SOURCE_DIR/RollingHDZ.png" ]; then
  log_msg "publishWeb.sh         : FAILED - missing RollingHDZ.png while plot_hdz=true" >> "$ERROR_LOG"
  exit 1
fi

if [ "$PLOT_BI" = "true" ] && [ ! -f "$SOURCE_DIR/RollingBI.png" ]; then
  log_msg "publishWeb.sh         : FAILED - missing RollingBI.png while plot_bi=true" >> "$ERROR_LOG"
  exit 1
fi

mkdir -p "$DEST_ROLLING_DIR" "$DEST_STATUS_DIR" "$DEST_NOAA_DIR" "$DEST_KP_DIR"

PLOT_OPTIONS_TEMP=$(mktemp "$BASE_PATH/data/status/.plot-options.XXXXXX")
printf '{"plot_hdz":%s,"plot_bi":%s,"plot_noaa":%s,"plot_kp":%s,"noaa_hemisphere":"%s"}\n' \
  "$PLOT_HDZ" "$PLOT_BI" "$PLOT_NOAA" "$PLOT_KP" "$NOAA_HEMISPHERE" \
  > "$PLOT_OPTIONS_TEMP"
mv -f "$PLOT_OPTIONS_TEMP" "$SOURCE_PLOT_OPTIONS"
chmod 644 "$SOURCE_PLOT_OPTIONS"
if [ "$(id -u)" -eq 0 ]; then
  chown "$FILE_OWNER:$FILE_GROUP" "$SOURCE_PLOT_OPTIONS"
fi
cp -a "$SOURCE_PLOT_OPTIONS" "$DEST_STATUS_DIR/plot-options.json"
chmod 644 "$DEST_STATUS_DIR/plot-options.json"

if cp -a "$SOURCE_DIR/RollingXYZ.png" "$DEST_ROLLING_DIR/" >> "$ERROR_LOG" 2>&1; then
  log_msg "publishWeb.sh         : Copied RollingXYZ.png to $DEST_ROLLING_DIR" >> "$MAIN_LOG"
else
  log_msg "publishWeb.sh         : FAILED - could not copy RollingXYZ.png" >> "$ERROR_LOG"
  exit 1
fi

if cp -a "$SOURCE_DIR/RollingActivity.png" "$DEST_ROLLING_DIR/" >> "$ERROR_LOG" 2>&1; then
  log_msg "publishWeb.sh         : Copied RollingActivity.png to $DEST_ROLLING_DIR" >> "$MAIN_LOG"
else
  log_msg "publishWeb.sh         : FAILED - could not copy RollingActivity.png" >> "$ERROR_LOG"
  exit 1
fi

if [ "$PLOT_HDZ" = "true" ]; then
  if cp -a "$SOURCE_DIR/RollingHDZ.png" "$DEST_ROLLING_DIR/" >> "$ERROR_LOG" 2>&1; then
    log_msg "publishWeb.sh         : Copied RollingHDZ.png to $DEST_ROLLING_DIR" >> "$MAIN_LOG"
  else
    log_msg "publishWeb.sh         : FAILED - could not copy RollingHDZ.png" >> "$ERROR_LOG"
    exit 1
  fi
elif [ -f "$DEST_ROLLING_DIR/RollingHDZ.png" ]; then
  rm -f "$DEST_ROLLING_DIR/RollingHDZ.png"
  log_msg "publishWeb.sh         : Removed stale RollingHDZ.png (plot_hdz=false)" >> "$MAIN_LOG"
else
  log_msg "publishWeb.sh         : Rolling HDZ not required (plot_hdz=false)" >> "$MAIN_LOG"
fi

if [ "$PLOT_BI" = "true" ]; then
  if cp -a "$SOURCE_DIR/RollingBI.png" "$DEST_ROLLING_DIR/" >> "$ERROR_LOG" 2>&1; then
    log_msg "publishWeb.sh         : Copied RollingBI.png to $DEST_ROLLING_DIR" >> "$MAIN_LOG"
  else
    log_msg "publishWeb.sh         : FAILED - could not copy RollingBI.png" >> "$ERROR_LOG"
    exit 1
  fi
elif [ -f "$DEST_ROLLING_DIR/RollingBI.png" ]; then
  rm -f "$DEST_ROLLING_DIR/RollingBI.png"
  log_msg "publishWeb.sh         : Removed stale RollingBI.png (plot_bi=false)" >> "$MAIN_LOG"
else
  log_msg "publishWeb.sh         : Rolling BI not required (plot_bi=false)" >> "$MAIN_LOG"
fi

if cp -a "$SOURCE_STATUS" "$DEST_STATUS_DIR/current.json" >> "$ERROR_LOG" 2>&1; then
  log_msg "publishWeb.sh         : Copied current.json to $DEST_STATUS_DIR" >> "$MAIN_LOG"
else
  log_msg "publishWeb.sh         : FAILED - could not copy current.json" >> "$ERROR_LOG"
  exit 1
fi

if [ "$PLOT_NOAA" = "true" ]; then
  if [ -f "$SOURCE_NOAA" ]; then
    if cp -a "$SOURCE_NOAA" "$DEST_NOAA_DIR/latest.jpg" >> "$ERROR_LOG" 2>&1; then
      chmod 644 "$DEST_NOAA_DIR/latest.jpg"
      log_msg "publishWeb.sh         : Copied NOAA aurora forecast to $DEST_NOAA_DIR" >> "$MAIN_LOG"
    else
      log_msg "publishWeb.sh         : WARNING - could not copy NOAA aurora forecast" >> "$ERROR_LOG"
    fi
  else
    log_msg "publishWeb.sh         : NOAA aurora forecast not present, skipping" >> "$MAIN_LOG"
  fi
else
  if [ -f "$DEST_NOAA_DIR/latest.jpg" ]; then
    rm -f "$DEST_NOAA_DIR/latest.jpg"
    log_msg "publishWeb.sh         : Removed stale NOAA aurora forecast (plot_noaa=false)" >> "$MAIN_LOG"
  else
    log_msg "publishWeb.sh         : NOAA aurora forecast not required (plot_noaa=false)" >> "$MAIN_LOG"
  fi
fi

if [ "$PLOT_KP" = "true" ]; then
  if [ -f "$SOURCE_KP" ]; then
    if cp -a "$SOURCE_KP" "$DEST_KP_DIR/PlanetaryKp.png" >> "$ERROR_LOG" 2>&1; then
      chmod 644 "$DEST_KP_DIR/PlanetaryKp.png"
      log_msg "publishWeb.sh         : Copied planetary Kp forecast to $DEST_KP_DIR" >> "$MAIN_LOG"
    else
      log_msg "publishWeb.sh         : WARNING - could not copy planetary Kp forecast" >> "$ERROR_LOG"
    fi
  else
    log_msg "publishWeb.sh         : Planetary Kp forecast not present, skipping" >> "$MAIN_LOG"
  fi
elif [ -f "$DEST_KP_DIR/PlanetaryKp.png" ]; then
  rm -f "$DEST_KP_DIR/PlanetaryKp.png"
  log_msg "publishWeb.sh         : Removed stale planetary Kp forecast (plot_kp=false)" >> "$MAIN_LOG"
fi

log_msg "publishWeb.sh         : Completed publishing rolling web assets" >> "$MAIN_LOG"
