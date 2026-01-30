#!/bin/bash

# data bash script - scrape, process and plot

# entry to process yesterdays data
su pi -c "/usr/bin/python3 /home/pi/UKRAA_Magnetometer/scripts/ProcessDataRawACM0.py \
                        >> /home/pi/UKRAA_Magnetometer/logfiles/log-MagnetometerACM0.txt \
                       2>> /home/pi/UKRAA_Magnetometer/logfiles/log-error.txt"

# entry to plot yesterdays XYZ magnetic data
su pi -c "/usr/bin/gnuplot /home/pi/UKRAA_Magnetometer/scripts/PlotDataXYZACM0.gp\
                        >> /home/pi/UKRAA_Magnetometer/logfiles/log-MagnetometerACM0.txt \
                       2>> /home/pi/UKRAA_Magnetometer/logfiles/log-error.txt"

# entry to plot yesterdays HDZ magnetic data
su pi -c "/usr/bin/gnuplot /home/pi/UKRAA_Magnetometer/scripts/PlotDataHDZACM0.gp\
                        >> /home/pi/UKRAA_Magnetometer/logfiles/log-MagnetometerACM0.txt \
                       2>> /home/pi/UKRAA_Magnetometer/logfiles/log-error.txt"

# entry to plot yesterdays BI magnetic data
su pi -c "/usr/bin/gnuplot /home/pi/UKRAA_Magnetometer/scripts/PlotDataBIACM0.gp\
                        >> /home/pi/UKRAA_Magnetometer/logfiles/log-MagnetometerACM0.txt \
                       2>> /home/pi/UKRAA_Magnetometer/logfiles/log-error.txt"

