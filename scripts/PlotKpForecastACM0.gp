#!/usr/bin/gnuplot -persist

reset

basePath = system("sh -lc 'printf %s \"${MAGNETOMETER_BASE_PATH:-/home/pi/UKRAA_Magnetometer}\"'")
kpData = basePath."/data/kp/latest.csv"
archivePlot = basePath."/plots/kp/PlanetaryKp.png"
tempPlot = basePath."/temp/kp/PlanetaryKp.png"

system("sh -lc 'mkdir -p \"".basePath."/plots/kp\" \"".basePath."/temp/kp\"'")

set terminal pngcairo background "#ffffff" enhanced font "DejaVuSansCondensed,10" size 960,780 rounded
set datafile separator ","
set xdata time
set timefmt "%Y-%m-%d %H:%M:%S"
set format x "%d %b\n%H:%M"
set xtics 12*60*60
set mxtics 2
set grid xtics ytics
set boxwidth 9000 absolute
set style fill solid 0.9 noborder
set yrange [0:9]
set ytics 0,1,9
set xlabel "Forecast time (UTC)"
set ylabel "Planetary Kp index"
set title "NOAA Planetary Kp Index Forecast\nUpdated hourly from NOAA SWPC forecast data"
set key outside bottom center horizontal

set object 1 rect from graph 0, first 0 to graph 1, first 5 fc rgb "#d9f2e2" behind
set object 2 rect from graph 0, first 5 to graph 1, first 6 fc rgb "#fff2cc" behind
set object 3 rect from graph 0, first 6 to graph 1, first 7 fc rgb "#ffe5b4" behind
set object 4 rect from graph 0, first 7 to graph 1, first 8 fc rgb "#f8d7da" behind
set object 5 rect from graph 0, first 8 to graph 1, first 9 fc rgb "#efc1c1" behind

set output archivePlot
plot kpData using 1:($2 < 5 ? $2 : 1/0) with boxes lc rgb "#2f6f44" title "Quiet: Kp < 5", \
     kpData using 1:($2 >= 5 && $2 < 6 ? $2 : 1/0) with boxes lc rgb "#b8860b" title "G1: Kp 5-<6", \
     kpData using 1:($2 >= 6 && $2 < 7 ? $2 : 1/0) with boxes lc rgb "#cc7000" title "G2: Kp 6-<7", \
     kpData using 1:($2 >= 7 && $2 < 8 ? $2 : 1/0) with boxes lc rgb "#9f2d2d" title "G3: Kp 7-<8", \
     kpData using 1:($2 >= 8 && $2 < 9 ? $2 : 1/0) with boxes lc rgb "#7f1d1d" title "G4: Kp 8-<9", \
     kpData using 1:($2 >= 9 ? $2 : 1/0) with boxes lc rgb "#7a1f5c" title "G5: Kp 9"
set output

set output tempPlot
replot
set output