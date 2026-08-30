#!/bin/bash

BASE_PATH=${MAGNETOMETER_BASE_PATH:-/home/pi/UKRAA_Magnetometer}
LOG_DIR="$BASE_PATH/logfiles"
MAIN_LOG="$LOG_DIR/log-MagnetometerACM0.txt"
ERROR_LOG="$LOG_DIR/log-error.txt"

log_msg() {
    printf '%s : %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1"
}

log_msg "testRemoteUploadACM0.sh   : Started remote upload test" >> "$MAIN_LOG"

if MAGNETOMETER_BASE_PATH="$BASE_PATH" /bin/bash "$BASE_PATH/scripts/uploadRemoteACM0.sh" daily; then
    log_msg "testRemoteUploadACM0.sh   : Completed daily remote upload test" >> "$MAIN_LOG"
else
    log_msg "testRemoteUploadACM0.sh   : FAILED daily remote upload test" >> "$ERROR_LOG"
    exit 1
fi

if MAGNETOMETER_BASE_PATH="$BASE_PATH" /bin/bash "$BASE_PATH/scripts/uploadRemoteACM0.sh" rolling; then
    log_msg "testRemoteUploadACM0.sh   : Completed rolling remote upload test" >> "$MAIN_LOG"
else
    log_msg "testRemoteUploadACM0.sh   : FAILED rolling remote upload test" >> "$ERROR_LOG"
    exit 1
fi

log_msg "testRemoteUploadACM0.sh   : Completed remote upload test" >> "$MAIN_LOG"
