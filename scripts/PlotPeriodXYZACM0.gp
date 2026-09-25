#!/usr/bin/gnuplot -persist

plotFamily = "XYZ"
load system("sh -lc 'printf %s \"${MAGNETOMETER_BASE_PATH:-/home/pi/UKRAA_Magnetometer}\"'")."/scripts/PlotPeriodACM0.gp"