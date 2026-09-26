#!/bin/bash

# script managelogfiles.sh keeps older copies of log files.
# runs once per week (Sunday 00:00) via cron

source "$(dirname "${BASH_SOURCE[0]}")/magnetometer-env.sh"
LOG_DIR="$BASE_PATH/logfiles"
MAIN_LOG="$LOG_DIR/log-Magnetometer.txt"
ERROR_LOG="$LOG_DIR/log-error.txt"
SUMMARY_LOG="$LOG_DIR/dashboard-summary.log"

source "$(dirname "${BASH_SOURCE[0]}")/logging.sh"

log_msg() {
    write_log_entry "$1"
}

log_msg "manageLogfiles.sh         : Started rotating log files" >> "$MAIN_LOG"

# go to logfile directory
cd "$LOG_DIR"

# move logfile-1 to logfile-2
if [ -r log-error-1.txt ]; then
    log_msg "manageLogfiles.sh         : Renaming log-error-1.txt to log-error-2.txt" >> "$MAIN_LOG"
    su "$FILE_OWNER" -c "mv -f log-error-1.txt log-error-2.txt"
fi
if [ -r log-Magnetometer-1.txt ]; then
    log_msg "manageLogfiles.sh         : Renaming log-Magnetometer-1.txt to log-Magnetometer-2.txt" >> "$MAIN_LOG"
    su "$FILE_OWNER" -c "mv -f log-Magnetometer-1.txt log-Magnetometer-2.txt"
fi
if [ -r dashboard-summary-1.log ]; then
    log_msg "manageLogfiles.sh         : Renaming dashboard-summary-1.log to dashboard-summary-2.log" >> "$MAIN_LOG"
    su "$FILE_OWNER" -c "mv -f dashboard-summary-1.log dashboard-summary-2.log"
fi

# move logfile-0 to logfile-1
if [ -r log-error-0.txt ]; then
    log_msg "manageLogfiles.sh         : Renaming log-error-0.txt to log-error-1.txt" >> "$MAIN_LOG"
    su "$FILE_OWNER" -c "mv -f log-error-0.txt log-error-1.txt"
fi
if [ -r log-Magnetometer-0.txt ]; then
    log_msg "manageLogfiles.sh         : Renaming log-Magnetometer-0.txt to log-Magnetometer-1.txt" >> "$MAIN_LOG"
    su "$FILE_OWNER" -c "mv -f log-Magnetometer-0.txt log-Magnetometer-1.txt"
fi
if [ -r dashboard-summary-0.log ]; then
    log_msg "manageLogfiles.sh         : Renaming dashboard-summary-0.log to dashboard-summary-1.log" >> "$MAIN_LOG"
    su "$FILE_OWNER" -c "mv -f dashboard-summary-0.log dashboard-summary-1.log"
fi

# move current logfile to logfile-0
if [ -r log-error.txt ]; then
    log_msg "manageLogfiles.sh         : Renaming log-error.txt to log-error-0.txt" >> "$MAIN_LOG"
    su "$FILE_OWNER" -c "mv -f log-error.txt log-error-0.txt"
fi
if [ -r log-Magnetometer.txt ]; then
    log_msg "manageLogfiles.sh         : Renaming log-Magnetometer.txt to log-Magnetometer-0.txt" >> "$MAIN_LOG"
    log_msg "manageLogfiles.sh         : Completed rotating log files" >> "$MAIN_LOG"
    su "$FILE_OWNER" -c "mv -f log-Magnetometer.txt log-Magnetometer-0.txt"
fi
if [ -r dashboard-summary.log ]; then
    log_msg "manageLogfiles.sh         : Renaming dashboard-summary.log to dashboard-summary-0.log" >> "$MAIN_LOG"
    su "$FILE_OWNER" -c "mv -f dashboard-summary.log dashboard-summary-0.log"
fi

# create new empty logfile
> log-Magnetometer.txt
log_msg "manageLogfiles.sh         : Created new log-Magnetometer.txt" >> "$MAIN_LOG"
> log-error.txt
log_msg "manageLogfiles.sh         : Created new log-error.txt" >> "$MAIN_LOG"
> dashboard-summary.log
log_msg "manageLogfiles.sh         : Created new dashboard-summary.log" >> "$MAIN_LOG"

# change owner from root to the installation account for new log files
chown "$FILE_OWNER:$FILE_GROUP" log-Magnetometer.txt log-error.txt dashboard-summary.log
chmod 664 log-Magnetometer.txt log-error.txt dashboard-summary.log

