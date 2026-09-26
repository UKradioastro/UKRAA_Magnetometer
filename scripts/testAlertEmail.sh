#!/bin/bash

source "$(dirname "${BASH_SOURCE[0]}")/magnetometer-env.sh"
LOG_DIR="$BASE_PATH/logfiles"
MAIN_LOG="$LOG_DIR/log-Magnetometer.txt"
ERROR_LOG="$LOG_DIR/log-error.txt"

source "$(dirname "${BASH_SOURCE[0]}")/logging.sh"

log_msg() {
    write_log_entry "$1"
}

log_msg "testAlertEmail.sh     : Started SMTP test email" >> "$MAIN_LOG"

if MAGNETOMETER_BASE_PATH="$BASE_PATH" su "$FILE_OWNER" -c "/usr/bin/python3 $BASE_PATH/scripts/EvaluateAlerts.py --test-email >> $MAIN_LOG 2>> $ERROR_LOG"; then
    log_msg "testAlertEmail.sh     : Completed SMTP test email" >> "$MAIN_LOG"
else
    log_msg "testAlertEmail.sh     : FAILED SMTP test email" >> "$ERROR_LOG"
    exit 1
fi
