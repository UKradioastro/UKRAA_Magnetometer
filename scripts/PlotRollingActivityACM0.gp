#!/usr/bin/gnuplot -persist

reset

basePath = system("sh -lc 'printf %s \"${MAGNETOMETER_BASE_PATH:-/home/pi/UKRAA_Magnetometer}\"'")
rollingData = basePath."/data/rolling/latest-24h.csv"
archivePlot = basePath."/plots/rolling/RollingActivity.png"
tempPlot = basePath."/temp/rolling/RollingActivity.png"
yellowThreshold = real(system("sh -lc 'printf %s \"${MAGNETOMETER_ALERT_YELLOW_NT:-50}\"'"))
amberThreshold = real(system("sh -lc 'printf %s \"${MAGNETOMETER_ALERT_AMBER_NT:-100}\"'"))
redThreshold = real(system("sh -lc 'printf %s \"${MAGNETOMETER_ALERT_RED_NT:-200}\"'"))

system("sh -lc 'mkdir -p \"".basePath."/plots/rolling\" \"".basePath."/temp/rolling\"'")

set terminal pngcairo \
             background "#ffffff" \
             enhanced \
             font "DejaVuSansCondensed,10" \
             size 960,420 \
             rounded

set datafile separator ","

stats rollingData using 9 output prefix "ASTAT" nooutput
startX = system("sh -lc 'head -n 1 \"".rollingData."\" | cut -d, -f1'")
endX = system("sh -lc 'tail -n 1 \"".rollingData."\" | cut -d, -f1'")
topRange = (ASTAT_max > redThreshold ? ASTAT_max + 10 : redThreshold + 10)

set xdata time
set timefmt "%Y-%m-%d %H:%M:%S"
set format x "%H:%M"
set grid xtics ytics
set key outside above center
set style fill solid 0.35 noborder
set boxwidth 40

set xrange [startX:endX]
set yrange [0:topRange]
set xlabel "Time (UTC)"
set ylabel "Activity (nT)"
set object 1 rect from graph 0, graph 0 to graph 1, first yellowThreshold fc rgb "#d9f2e2" behind
set object 2 rect from graph 0, first yellowThreshold to graph 1, first amberThreshold fc rgb "#fff2cc" behind
set object 3 rect from graph 0, first amberThreshold to graph 1, first redThreshold fc rgb "#ffe5b4" behind
set object 4 rect from graph 0, first redThreshold to graph 1, graph 1 fc rgb "#f8d7da" behind
set arrow 1 from graph 0, first yellowThreshold to graph 1, first yellowThreshold nohead dt 2 lc rgb "#4f8a10"
set arrow 2 from graph 0, first amberThreshold to graph 1, first amberThreshold nohead dt 2 lc rgb "#b36b00"
set arrow 3 from graph 0, first redThreshold to graph 1, first redThreshold nohead dt 2 lc rgb "#b94a48"

set output archivePlot
plot rollingData using 1:9 with lines linewidth 1.5 linecolor rgb "#1f4e79" title "1-minute activity", \
     rollingData using 1:9 with filledcurves x1 linecolor rgb "#8ecae6" title "Activity area"
set output

set output tempPlot
replot
set output