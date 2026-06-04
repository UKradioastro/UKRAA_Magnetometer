#!/bin/bash

# script managelogfiles.sh keeps older copies of log files.
# runs once per week (Sunday 00:00) via cron

LOG_DIR=/home/pi/UKRAA_Magnetometer/logfiles
MAIN_LOG="$LOG_DIR/log-MagnetometerACM0.txt"
ERROR_LOG="$LOG_DIR/log-error.txt"

log_msg() {
    printf '%s : %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1"
}

log_msg "manageLogfiles.sh : Started rotating log files" >> "$MAIN_LOG"

# go to logfile directory
cd "$LOG_DIR"

# move logfile-1 to logfile-2
if [ -r log-MagnetometerACM0-1.txt ]; then
    log_msg "manageLogfiles.sh : Renaming log-MagnetometerACM0-1.txt to log-MagnetometerACM0-2.txt" >> "$MAIN_LOG"
    su pi -c "mv -f log-MagnetometerACM0-1.txt log-MagnetometerACM0-2.txt"
fi
if [ -r log-error-1.txt ]; then
    log_msg "manageLogfiles.sh : Renaming log-error-1.txt to log-error-2.txt" >> "$MAIN_LOG"
    su pi -c "mv -f log-error-1.txt log-error-2.txt"
fi

# move logfile-0 to logfile-1
if [ -r log-MagnetometerACM0-0.txt ]; then
    log_msg "manageLogfiles.sh : Renaming log-MagnetometerACM0-0.txt to log-MagnetometerACM0-1.txt" >> "$MAIN_LOG"
    su pi -c "mv -f log-MagnetometerACM0-0.txt log-MagnetometerACM0-1.txt"
fi
if [ -r log-error-0.txt ]; then
    log_msg "manageLogfiles.sh : Renaming log-error-0.txt to log-error-1.txt" >> "$MAIN_LOG"
    su pi -c "mv -f log-error-0.txt log-error-1.txt"
fi

# move current logfile to logfile-0
if [ -r log-MagnetometerACM0.txt ]; then
    log_msg "manageLogfiles.sh : Renaming log-MagnetometerACM0.txt to log-MagnetometerACM0-0.txt" >> "$MAIN_LOG"
    su pi -c "mv -f log-MagnetometerACM0.txt log-MagnetometerACM0-0.txt"
fi
if [ -r log-error.txt ]; then
    log_msg "manageLogfiles.sh : Renaming log-error.txt to log-error-0.txt" >> "$MAIN_LOG"
    su pi -c "mv -f log-error.txt log-error-0.txt"
fi

# create new empty logfile
log_msg "manageLogfiles.sh : Truncating log-MagnetometerACM0.txt" >> "$MAIN_LOG"
su pi -c "cat /dev/null > log-MagnetometerACM0.txt"
log_msg "manageLogfiles.sh : Truncating log-error.txt" >> "$MAIN_LOG"
su pi -c "cat /dev/null > log-error.txt"

log_msg "manageLogfiles.sh : Completed rotating log files" >> "$MAIN_LOG"
