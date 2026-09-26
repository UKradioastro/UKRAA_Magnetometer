#!/bin/bash

BASE_PATH=${MAGNETOMETER_BASE_PATH:-/home/pi/UKRAA_Magnetometer}
LOG_DIR="$BASE_PATH/logfiles"
MAIN_LOG="$LOG_DIR/log-Magnetometer.txt"
ERROR_LOG="$LOG_DIR/log-error.txt"

source "$(dirname "${BASH_SOURCE[0]}")/logging.sh"

log_msg() {
    write_log_entry "$1"
}

log_msg "testHeartbeatEmail.sh : Started heartbeat test email" >> "$MAIN_LOG"

if MAGNETOMETER_BASE_PATH="$BASE_PATH" su pi -c "/usr/bin/python3 $BASE_PATH/scripts/EvaluateAlerts.py --test-heartbeat >> $MAIN_LOG 2>> $ERROR_LOG"; then
    log_msg "testHeartbeatEmail.sh : Completed heartbeat test email" >> "$MAIN_LOG"
else
    log_msg "testHeartbeatEmail.sh : FAILED heartbeat test email" >> "$ERROR_LOG"
    exit 1
fi
