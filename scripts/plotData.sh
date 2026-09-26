#!/bin/bash

source "$(dirname "${BASH_SOURCE[0]}")/magnetometer-env.sh"

echo "Start plotting yesterday's graphs..."

# cron entry to plot yesterdays counts per minute
su "$FILE_OWNER" -c "/usr/bin/gnuplot $BASE_PATH/scripts/PlotDataXYZ.gp \
                        >> $BASE_PATH/logfiles/log-Magnetometer.txt \
                       2>> $BASE_PATH/logfiles/log-error.txt"

# cron entry to plot yesterdays counts per minute frequency
su "$FILE_OWNER" -c "/usr/bin/gnuplot $BASE_PATH/scripts/PlotDataActivity.gp \
                        >> $BASE_PATH/logfiles/log-Magnetometer.txt \
                       2>> $BASE_PATH/logfiles/log-error.txt"

echo "Completed plotting yesterday's graphs"