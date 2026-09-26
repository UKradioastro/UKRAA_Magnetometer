#!/usr/bin/gnuplot -persist

plotFamily = "HDZ"
load system("sh -lc 'printf %s \"${MAGNETOMETER_BASE_PATH:-$HOME/UKRAA_Magnetometer}\"'")."/scripts/PlotPeriod.gp"