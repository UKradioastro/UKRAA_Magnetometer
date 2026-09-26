#!/usr/bin/gnuplot -persist

plotFamily = "BI"
load system("sh -lc 'printf %s \"${MAGNETOMETER_BASE_PATH:-$HOME/UKRAA_Magnetometer}\"'")."/scripts/PlotPeriod.gp"