#!/bin/bash

echo "Start plotting yesterday's graphs..."

# cron entry to plot yesterdays counts per minute
su pi -c "/usr/bin/gnuplot /home/pi/UKRAA_Magnetometer/scripts/PlotDataXYZACM0.gp \
                        >> /home/pi/UKRAA_Magnetometer/logfiles/log-MagnetometerACM0.txt \
                       2>> /home/pi/UKRAA_Magnetometer/logfiles/log-error.txt"

# cron entry to plot yesterdays counts per minute frequency
su pi -c "/usr/bin/gnuplot /home/pi/UKRAA_Magnetometer/scripts/PlotDataActivityACM0.gp \
                        >> /home/pi/UKRAA_Magnetometer/logfiles/log-MagnetometerACM0.txt \
                       2>> /home/pi/UKRAA_Magnetometer/logfiles/log-error.txt"

echo "Completed plotting yesterday's graphs"