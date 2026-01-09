#!/bin/bash

# script managelogfiles.sh keeps older copies of log files.
# runs once per week (Sunday 00:00) via cron

# go to logfile directory
cd /home/pi/UKRAA_Magnetometer/logfiles

# move logfile-1 to logfile-2
if [ -r log-MagnetometerACM0-1.txt ]; then
    su pi -c "mv -f log-MagnetometerACM0-1.txt log-MagnetometerACM0-2.txt"
fi
if [ -r log-error-1.txt ]; then
    su pi -c "mv -f log-error-1.txt log-error-2.txt"
fi

# move logfile-0 to logfile-1
if [ -r log-MagnetometerACM0-0.txt ]; then
    su pi -c "mv -f log-MagnetometerACM0-0.txt log-MagnetometerACM0-1.txt"
fi
if [ -r log-error-0.txt ]; then
    su pi -c "mv -f log-error-0.txt log-error-1.txt"
fi

# move current logfile to logfile-0
if [ -r log-MagnetometerACM0.txt ]; then
    su pi -c "mv -f log-MagnetometerACM0.txt log-MagnetometerACM0-0.txt"
fi
if [ -r log-error.txt ]; then
    su pi -c "mv -f log-error.txt log-error-0.txt"
fi

# create new empty logfile
su pi -c "cat /dev/null > log-MagnetometerACM0.txt"
su pi -c "cat /dev/null > log-error.txt"
