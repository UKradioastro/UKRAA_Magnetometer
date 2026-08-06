#!/bin/bash

# script moveGraphs.sh to move yesterdays graphs to /var/www/html.
# runs once per day (09:30) via cron

LOG_DIR=/home/pi/UKRAA_Magnetometer/logfiles
MAIN_LOG="$LOG_DIR/log-MagnetometerACM0.txt"
ERROR_LOG="$LOG_DIR/log-error.txt"

# logfile message function
log_msg() {
    printf '%s : %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1"
}

# log message to main logfile
log_msg "moveGraphs.sh           : Started moving graphs" >> "$MAIN_LOG"

# source directory to copy from
SOURCE_DIR=/home/pi/UKRAA_Magnetometer/temp

# fail fast if the source directory is missing
if [ ! -d "$SOURCE_DIR" ]; then
  log_msg "moveGraphs.sh           : FAILED - look in log-error.txt for details" >> "$MAIN_LOG"
  log_msg "moveGraphs.sh           : FAILED - source directory missing: $SOURCE_DIR" >> "$ERROR_LOG"
  exit 1
fi

# fail fast if the source directory is empty
if ! find "$SOURCE_DIR" -mindepth 1 -maxdepth 1 -print -quit | grep -q .; then
  log_msg "moveGraphs.sh           : FAILED - look in log-error.txt for details" >> "$MAIN_LOG"
  log_msg "moveGraphs.sh           : FAILED - source directory empty: $SOURCE_DIR" >> "$ERROR_LOG"
  exit 1
fi

# required graph files for the daily web page
REQUIRED_FILES="Activity.png X.png Y.png Z.png"

# fail fast if any required file is missing
for required_file in $REQUIRED_FILES; do
  if [ ! -f "$SOURCE_DIR/$required_file" ]; then
    log_msg "moveGraphs.sh           : FAILED - look in log-error.txt for details" >> "$MAIN_LOG"
    log_msg "moveGraphs.sh           : FAILED - missing required file: $SOURCE_DIR/$required_file" >> "$ERROR_LOG"
    exit 1
  fi
done

# entry to move yesterdays graphs from temp to /var/www/html
COPY_OUTPUT_FILE=$(mktemp)

if cp -av "$SOURCE_DIR" /var/www/html/ \
     > "$COPY_OUTPUT_FILE" \
     2>> "$ERROR_LOG"
then
  while IFS= read -r line; do
    if [ -n "$line" ]; then
      log_msg "moveGraphs.sh           : moved $line" >> "$MAIN_LOG"
    fi
  done < "$COPY_OUTPUT_FILE"

  log_msg "moveGraphs.sh           : Completed moving graphs" >> "$MAIN_LOG"

  if /bin/bash /home/pi/UKRAA_Magnetometer/scripts/uploadRemoteACM0.sh daily; then
    log_msg "moveGraphs.sh           : Completed remote daily upload" >> "$MAIN_LOG"
  else
    log_msg "moveGraphs.sh           : FAILED remote daily upload (local publish kept)" >> "$ERROR_LOG"
  fi
else
  log_msg "moveGraphs.sh           : FAILED - look in log-error.txt for details" >> "$MAIN_LOG"
  log_msg "moveGraphs.sh           : FAILED to move graphs" >> "$ERROR_LOG"
  exit 1
fi

rm -f "$COPY_OUTPUT_FILE"