#!/usr/bin/gnuplot -persist

reset

basePath = system("sh -lc 'printf %s \"${MAGNETOMETER_BASE_PATH:-/home/pi/UKRAA_Magnetometer}\"'")
rollingData = basePath."/data/rolling/latest-24h.csv"
archivePlot = basePath."/plots/rolling/RollingXYZ.png"
tempPlot = basePath."/temp/rolling/RollingXYZ.png"

system("sh -lc 'mkdir -p \"".basePath."/plots/rolling\" \"".basePath."/temp/rolling\"'")

set terminal pngcairo \
             background "#ffffff" \
             enhanced \
             font "DejaVuSansCondensed,10" \
             size 960,960 \
             rounded

set datafile separator ","

stats rollingData using 5 output prefix "XSTAT" nooutput
stats rollingData using 6 output prefix "YSTAT" nooutput
stats rollingData using 7 output prefix "ZSTAT" nooutput

set xdata time
set timefmt "%Y-%m-%d %H:%M:%S"
set format x "%H:%M"
set grid xtics ytics
set key outside above center
set lmargin 10
set rmargin 4

startX = system("sh -lc 'head -n 1 \"".rollingData."\" | cut -d, -f1'")
endX = system("sh -lc 'tail -n 1 \"".rollingData."\" | cut -d, -f1'")

set xrange [startX:endX]
set output archivePlot
set multiplot layout 3,1 title "Rolling magnetic field for the last 24 hours\nUpdated every 5 minutes" font ",12"

set ylabel "X (nT)"
set yrange [XSTAT_min - 200:XSTAT_max + 200]
plot rollingData using 1:5 with lines linewidth 1.2 linecolor rgb "#0b61ff" title "X magnetic field"

set ylabel "Y (nT)"
set yrange [YSTAT_min - 200:YSTAT_max + 200]
plot rollingData using 1:6 with lines linewidth 1.2 linecolor rgb "#e24329" title "Y magnetic field"

set ylabel "Z (nT)"
set xlabel "Time (UTC)"
set yrange [ZSTAT_min - 200:ZSTAT_max + 200]
plot rollingData using 1:7 with lines linewidth 1.2 linecolor rgb "#1a8f4b" title "Z magnetic field"

unset multiplot
set output

set output tempPlot
set multiplot layout 3,1 title "Rolling magnetic field for the last 24 hours\nUpdated every 5 minutes" font ",12"

set ylabel "X (nT)"
set yrange [XSTAT_min - 200:XSTAT_max + 200]
plot rollingData using 1:5 with lines linewidth 1.2 linecolor rgb "#0b61ff" title "X magnetic field"

set ylabel "Y (nT)"
set yrange [YSTAT_min - 200:YSTAT_max + 200]
plot rollingData using 1:6 with lines linewidth 1.2 linecolor rgb "#e24329" title "Y magnetic field"

set ylabel "Z (nT)"
set xlabel "Time (UTC)"
set yrange [ZSTAT_min - 200:ZSTAT_max + 200]
plot rollingData using 1:7 with lines linewidth 1.2 linecolor rgb "#1a8f4b" title "Z magnetic field"

unset multiplot
set output