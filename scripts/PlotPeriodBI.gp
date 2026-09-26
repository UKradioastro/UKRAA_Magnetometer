#!/usr/bin/gnuplot -persist

plotFamily = "BI"
load system("sh -lc 'printf %s \"${MAGNETOMETER_BASE_PATH:-/home/pi/UKRAA_Magnetometer}\"'")."/scripts/PlotPeriod.gp"