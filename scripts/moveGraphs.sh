#!/bin/bash

# script moveGraphs.sh to move yesterdays graphs to /var/www/html.
# runs once per day (09:30) via cron

BASE_PATH=${MAGNETOMETER_BASE_PATH:-/home/pi/UKRAA_Magnetometer}
WEB_ROOT=${MAGNETOMETER_WEB_ROOT:-/var/www/html}

LOG_DIR="$BASE_PATH/logfiles"
MAIN_LOG="$LOG_DIR/log-MagnetometerACM0.txt"
ERROR_LOG="$LOG_DIR/log-error.txt"

# logfile message function
log_msg() {
    printf '%s : %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1"
}

# log message to main logfile
log_msg "moveGraphs.sh             : Started moving graphs" >> "$MAIN_LOG"

# source directory to copy from
SOURCE_DIR="$BASE_PATH/temp"

# fail fast if the source directory is missing
if [ ! -d "$SOURCE_DIR" ]; then
  log_msg "moveGraphs.sh             : FAILED - look in log-error.txt for details" >> "$MAIN_LOG"
  log_msg "moveGraphs.sh             : FAILED - source directory missing: $SOURCE_DIR" >> "$ERROR_LOG"
  exit 1
fi

# fail fast if the source directory is empty
if ! find "$SOURCE_DIR" -mindepth 1 -maxdepth 1 -print -quit | grep -q .; then
  log_msg "moveGraphs.sh             : FAILED - look in log-error.txt for details" >> "$MAIN_LOG"
  log_msg "moveGraphs.sh             : FAILED - source directory empty: $SOURCE_DIR" >> "$ERROR_LOG"
  exit 1
fi

# required graph files for the daily web page
REQUIRED_FILES="Activity.png XYZ.png"

# fail fast if any required file is missing
for required_file in $REQUIRED_FILES; do
  if [ ! -f "$SOURCE_DIR/$required_file" ]; then
    log_msg "moveGraphs.sh             : FAILED - look in log-error.txt for details" >> "$MAIN_LOG"
    log_msg "moveGraphs.sh             : FAILED - missing required file: $SOURCE_DIR/$required_file" >> "$ERROR_LOG"
    exit 1
  fi
done

# read HDZ and BI plot flags from plot.ini (defaults: true true)
if ! PLOT_OPTIONS=$(/usr/bin/python3 "$BASE_PATH/scripts/GetPlotOptionsACM0.py" 2>&1); then
  log_msg "moveGraphs.sh             : FAILED - look in log-error.txt for details" >> "$MAIN_LOG"
  log_msg "moveGraphs.sh             : FAILED to read plot options: $PLOT_OPTIONS" >> "$ERROR_LOG"
  exit 1
fi

read -r PLOT_HDZ PLOT_BI <<< "$PLOT_OPTIONS"

if [ -z "${PLOT_HDZ:-}" ] || [ -z "${PLOT_BI:-}" ]; then
  log_msg "moveGraphs.sh             : FAILED - look in log-error.txt for details" >> "$MAIN_LOG"
  log_msg "moveGraphs.sh             : FAILED - unexpected plot options output: '$PLOT_OPTIONS'" >> "$ERROR_LOG"
  exit 1
fi

if [ "$PLOT_HDZ" = "true" ]; then
  if [ ! -f "$SOURCE_DIR/HDZ.png" ]; then
      log_msg "moveGraphs.sh             : FAILED - look in log-error.txt for details" >> "$MAIN_LOG"
      log_msg "moveGraphs.sh             : FAILED - missing HDZ file while plot_hdz=true: $SOURCE_DIR/HDZ.png" >> "$ERROR_LOG"
      exit 1
  fi
  log_msg "moveGraphs.sh             : HDZ file detected (HDZ.png)" >> "$MAIN_LOG"
else
  if [ -f "$SOURCE_DIR/HDZ.png" ]; then
    rm -f "$SOURCE_DIR/HDZ.png"
    log_msg "moveGraphs.sh             : Removed stale HDZ.png from temp source (plot_hdz=false)" >> "$MAIN_LOG"
  fi
  if [ -f "$WEB_ROOT/temp/HDZ.png" ]; then
    rm -f "$WEB_ROOT/temp/HDZ.png"
    log_msg "moveGraphs.sh             : Removed stale HDZ.png from web root (plot_hdz=false)" >> "$MAIN_LOG"
  else
    log_msg "moveGraphs.sh             : HDZ files not required (plot_hdz=false)" >> "$MAIN_LOG"
  fi
fi

if [ "$PLOT_BI" = "true" ]; then
  if [ ! -f "$SOURCE_DIR/BI.png" ]; then
      log_msg "moveGraphs.sh             : FAILED - look in log-error.txt for details" >> "$MAIN_LOG"
      log_msg "moveGraphs.sh             : FAILED - missing BI file while plot_bi=true: $SOURCE_DIR/BI.png" >> "$ERROR_LOG"
      exit 1
  fi
  log_msg "moveGraphs.sh             : BI file detected (BI.png)" >> "$MAIN_LOG"
else
  if [ -f "$SOURCE_DIR/BI.png" ]; then
    rm -f "$SOURCE_DIR/BI.png"
    log_msg "moveGraphs.sh             : Removed stale BI.png from temp source (plot_bi=false)" >> "$MAIN_LOG"
  fi
  if [ -f "$WEB_ROOT/temp/BI.png" ]; then
    rm -f "$WEB_ROOT/temp/BI.png"
    log_msg "moveGraphs.sh             : Removed stale BI.png from web root (plot_bi=false)" >> "$MAIN_LOG"
  else
    log_msg "moveGraphs.sh             : BI files not required (plot_bi=false)" >> "$MAIN_LOG"
  fi
fi

# Older versions put test sandboxes under temp/, which then got published. Remove any leftovers.
for stale_dir in "$SOURCE_DIR"/test-* "$WEB_ROOT"/temp/test-*; do
  if [ -d "$stale_dir" ]; then
    rm -rf "$stale_dir"
    log_msg "moveGraphs.sh             : Removed stale test sandbox $stale_dir" >> "$MAIN_LOG"
  fi
done

# entry to move yesterdays graphs from temp to web root
COPY_OUTPUT_FILE=$(mktemp)

if cp -av "$SOURCE_DIR" "$WEB_ROOT/" \
     > "$COPY_OUTPUT_FILE" \
     2>> "$ERROR_LOG"
then
  while IFS= read -r line; do
    if [ -n "$line" ]; then
      log_msg "moveGraphs.sh             : moved $line" >> "$MAIN_LOG"
    fi
  done < "$COPY_OUTPUT_FILE"

  log_msg "moveGraphs.sh             : Completed moving graphs" >> "$MAIN_LOG"

  if /bin/bash "$BASE_PATH/scripts/uploadRemoteACM0.sh" daily; then
    log_msg "moveGraphs.sh             : Completed remote daily upload" >> "$MAIN_LOG"
  else
    log_msg "moveGraphs.sh             : FAILED remote daily upload (local publish kept)" >> "$ERROR_LOG"
  fi
else
  log_msg "moveGraphs.sh             : FAILED - look in log-error.txt for details" >> "$MAIN_LOG"
  log_msg "moveGraphs.sh             : FAILED to move graphs" >> "$ERROR_LOG"
  exit 1
fi

rm -f "$COPY_OUTPUT_FILE"