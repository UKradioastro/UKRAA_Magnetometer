#!/bin/bash

BASE_PATH=${MAGNETOMETER_BASE_PATH:-/home/pi/UKRAA_Magnetometer}
LOG_DIR="$BASE_PATH/logfiles"
MAIN_LOG="$LOG_DIR/log-Magnetometer.txt"
ERROR_LOG="$LOG_DIR/log-error.txt"

log_msg() {
    printf '%s : %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1"
}

log_msg "testAlertEmail.sh     : Started SMTP test email" >> "$MAIN_LOG"

if MAGNETOMETER_BASE_PATH="$BASE_PATH" su pi -c "/usr/bin/python3 $BASE_PATH/scripts/EvaluateAlerts.py --test-email >> $MAIN_LOG 2>> $ERROR_LOG"; then
    log_msg "testAlertEmail.sh     : Completed SMTP test email" >> "$MAIN_LOG"
else
    log_msg "testAlertEmail.sh     : FAILED SMTP test email" >> "$ERROR_LOG"
    exit 1
fi
