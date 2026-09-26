#!/bin/bash

BASE_PATH=${MAGNETOMETER_BASE_PATH:-/home/pi/UKRAA_Magnetometer}
LOG_DIR="$BASE_PATH/logfiles"
MAIN_LOG="$LOG_DIR/log-Magnetometer.txt"
ERROR_LOG="$LOG_DIR/log-error.txt"

source "$(dirname "${BASH_SOURCE[0]}")/logging.sh"

log_msg() {
    write_log_entry "$1"
}

log_msg "testRemoteUpload.sh   : Started remote upload test" >> "$MAIN_LOG"

if MAGNETOMETER_BASE_PATH="$BASE_PATH" /bin/bash "$BASE_PATH/scripts/uploadRemote.sh" daily; then
    log_msg "testRemoteUpload.sh   : Completed daily remote upload test" >> "$MAIN_LOG"
else
    log_msg "testRemoteUpload.sh   : FAILED daily remote upload test" >> "$ERROR_LOG"
    exit 1
fi

if MAGNETOMETER_BASE_PATH="$BASE_PATH" /bin/bash "$BASE_PATH/scripts/uploadRemote.sh" rolling; then
    log_msg "testRemoteUpload.sh   : Completed rolling remote upload test" >> "$MAIN_LOG"
else
    log_msg "testRemoteUpload.sh   : FAILED rolling remote upload test" >> "$ERROR_LOG"
    exit 1
fi

log_msg "testRemoteUpload.sh   : Completed remote upload test" >> "$MAIN_LOG"
