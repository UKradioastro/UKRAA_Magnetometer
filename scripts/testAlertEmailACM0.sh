#!/bin/bash

BASE_PATH=${MAGNETOMETER_BASE_PATH:-/home/pi/UKRAA_Magnetometer}
LOG_DIR="$BASE_PATH/logfiles"
MAIN_LOG="$LOG_DIR/log-MagnetometerACM0.txt"
ERROR_LOG="$LOG_DIR/log-error.txt"

log_msg() {
    printf '%s : %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1"
}

log_msg "testAlertEmailACM0.sh   : Started SMTP test email" >> "$MAIN_LOG"

if MAGNETOMETER_BASE_PATH="$BASE_PATH" su pi -c "/usr/bin/python3 $BASE_PATH/scripts/EvaluateAlertsACM0.py --test-email >> $MAIN_LOG 2>> $ERROR_LOG"; then
    log_msg "testAlertEmailACM0.sh   : Completed SMTP test email" >> "$MAIN_LOG"
else
    log_msg "testAlertEmailACM0.sh   : FAILED SMTP test email" >> "$ERROR_LOG"
    exit 1
fi
