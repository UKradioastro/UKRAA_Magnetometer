#!/usr/bin/gnuplot -persist

reset

basePath = system("sh -lc 'printf %s \"${MAGNETOMETER_BASE_PATH:-/home/pi/UKRAA_Magnetometer}\"'")
windowName = system("sh -lc 'printf %s \"${MAGNETOMETER_HISTORY_WINDOW:-7d}\"'")
fileData = basePath."/data/history/".windowName."/history.csv"
archiveDir = basePath."/plots/history/".windowName
archivePlot = archiveDir."/".system("sh -lc 'if [ -n \"${MAGNETOMETER_TARGET_DATE:-}\" ]; then printf %s \"$MAGNETOMETER_TARGET_DATE\"; else date -d yesterday +%Y-%m-%d; fi'")."_BI.png"
tempDir = basePath."/temp/history/".windowName
tempPlot = tempDir."/BI.png"

system("sh -lc 'mkdir -p \"".archiveDir."\" \"".tempDir."\"'")

set terminal pngcairo background "#ffffff" enhanced font "DejaVuSansCondensed,10" size 960,760 rounded
set datafile separator ","
stats fileData using 13 output prefix "BSTAT" nooutput
stats fileData using 14 output prefix "ISTAT" nooutput
stats fileData using 8 output prefix "TSTAT" nooutput

tempPadding = 1.0
tempRangeMin = TSTAT_min - tempPadding
tempRangeMax = TSTAT_max + tempPadding
magneticColor = "#0000ff"
tempColor = "#a0a0a0"
fieldStatX = 0.02
tempStatX = 0.80
statTitleY = 0.95
statMeanY = 0.90
statMaxY = 0.85
statMinY = 0.80

set xdata time
set timefmt "%Y-%m-%d %H:%M:%S"
set format x "%m-%d %H:%M"
set format y2 "%.1f"
set grid xtics ytics
unset key
set lmargin 10
set rmargin 10
set y2tics

startX = system("sh -lc 'head -n 1 \"".fileData."\" | cut -d, -f1'")
endX = system("sh -lc 'tail -n 1 \"".fileData."\" | cut -d, -f1'")
plotTitle = sprintf("BI magnetic field for last %s\n%s UTC to %s UTC", windowName, startX, endX)
set xrange [startX:endX]

set output archivePlot
set multiplot layout 2,1 title plotTitle font ",12"

set ylabel "B (nT)"
set ylabel textcolor rgb magneticColor
set ytics textcolor rgb magneticColor
unset xlabel
set yrange [BSTAT_min - 100:BSTAT_max + 100]
set y2label "Temperature (°C)"
set y2label textcolor rgb tempColor
set y2tics textcolor rgb tempColor
set y2range [tempRangeMin:tempRangeMax]
set label 1 "B field statistics"
set label 1 at graph fieldStatX, statTitleY tc rgb magneticColor
set label 2 sprintf("Mean B(nT) : %0.1f nT", BSTAT_mean)
set label 2 at graph fieldStatX, statMeanY tc rgb magneticColor
set label 3 sprintf("Max B(nT) : %0.1f nT", BSTAT_max)
set label 3 at graph fieldStatX, statMaxY tc rgb magneticColor
set label 4 sprintf("Min B(nT) : %0.1f nT", BSTAT_min)
set label 4 at graph fieldStatX, statMinY tc rgb magneticColor
set label 11 "Temperature statistics"
set label 11 at graph tempStatX, statTitleY tc rgb tempColor
set label 12 sprintf("Mean Temp(C) : %0.1f °C", TSTAT_mean)
set label 12 at graph tempStatX, statMeanY tc rgb tempColor
set label 13 sprintf("Max Temp(C) : %0.1f °C", TSTAT_max)
set label 13 at graph tempStatX, statMaxY tc rgb tempColor
set label 14 sprintf("Min Temp(C) : %0.1f °C", TSTAT_min)
set label 14 at graph tempStatX, statMinY tc rgb tempColor
plot fileData using 1:13 with lines linewidth 1.2 linecolor rgb magneticColor notitle, \
    fileData using 1:8 axes x1y2 with lines linewidth 1.0 linecolor rgb tempColor notitle

set ylabel "I (deg)"
set ylabel textcolor rgb magneticColor
set ytics textcolor rgb magneticColor
set xlabel "Time (UTC)"
set yrange [ISTAT_min - 5:ISTAT_max + 5]
set y2label "Temperature (°C)"
set y2label textcolor rgb tempColor
set y2tics textcolor rgb tempColor
set y2range [tempRangeMin:tempRangeMax]
set label 1 "I angle statistics"
set label 1 at graph fieldStatX, statTitleY tc rgb magneticColor
set label 2 sprintf("Mean I(deg) : %0.1f deg", ISTAT_mean)
set label 2 at graph fieldStatX, statMeanY tc rgb magneticColor
set label 3 sprintf("Max I(deg) : %0.1f deg", ISTAT_max)
set label 3 at graph fieldStatX, statMaxY tc rgb magneticColor
set label 4 sprintf("Min I(deg) : %0.1f deg", ISTAT_min)
set label 4 at graph fieldStatX, statMinY tc rgb magneticColor
set label 11 "Temperature statistics"
set label 11 at graph tempStatX, statTitleY tc rgb tempColor
set label 12 sprintf("Mean Temp(C) : %0.1f °C", TSTAT_mean)
set label 12 at graph tempStatX, statMeanY tc rgb tempColor
set label 13 sprintf("Max Temp(C) : %0.1f °C", TSTAT_max)
set label 13 at graph tempStatX, statMaxY tc rgb tempColor
set label 14 sprintf("Min Temp(C) : %0.1f °C", TSTAT_min)
set label 14 at graph tempStatX, statMinY tc rgb tempColor
plot fileData using 1:14 with lines linewidth 1.2 linecolor rgb magneticColor notitle, \
    fileData using 1:8 axes x1y2 with lines linewidth 1.0 linecolor rgb tempColor notitle

unset multiplot
set output

set output tempPlot
set multiplot layout 2,1 title plotTitle font ",12"

set ylabel "B (nT)"
set ylabel textcolor rgb magneticColor
set ytics textcolor rgb magneticColor
unset xlabel
set yrange [BSTAT_min - 100:BSTAT_max + 100]
set y2label "Temperature (°C)"
set y2label textcolor rgb tempColor
set y2tics textcolor rgb tempColor
set y2range [tempRangeMin:tempRangeMax]
set label 1 "B field statistics"
set label 1 at graph fieldStatX, statTitleY tc rgb magneticColor
set label 2 sprintf("Mean B(nT) : %0.1f nT", BSTAT_mean)
set label 2 at graph fieldStatX, statMeanY tc rgb magneticColor
set label 3 sprintf("Max B(nT) : %0.1f nT", BSTAT_max)
set label 3 at graph fieldStatX, statMaxY tc rgb magneticColor
set label 4 sprintf("Min B(nT) : %0.1f nT", BSTAT_min)
set label 4 at graph fieldStatX, statMinY tc rgb magneticColor
set label 11 "Temperature statistics"
set label 11 at graph tempStatX, statTitleY tc rgb tempColor
set label 12 sprintf("Mean Temp(C) : %0.1f °C", TSTAT_mean)
set label 12 at graph tempStatX, statMeanY tc rgb tempColor
set label 13 sprintf("Max Temp(C) : %0.1f °C", TSTAT_max)
set label 13 at graph tempStatX, statMaxY tc rgb tempColor
set label 14 sprintf("Min Temp(C) : %0.1f °C", TSTAT_min)
set label 14 at graph tempStatX, statMinY tc rgb tempColor
plot fileData using 1:13 with lines linewidth 1.2 linecolor rgb magneticColor notitle, \
    fileData using 1:8 axes x1y2 with lines linewidth 1.0 linecolor rgb tempColor notitle

set ylabel "I (deg)"
set ylabel textcolor rgb magneticColor
set ytics textcolor rgb magneticColor
set xlabel "Time (UTC)"
set yrange [ISTAT_min - 5:ISTAT_max + 5]
set y2label "Temperature (°C)"
set y2label textcolor rgb tempColor
set y2tics textcolor rgb tempColor
set y2range [tempRangeMin:tempRangeMax]
set label 1 "I angle statistics"
set label 1 at graph fieldStatX, statTitleY tc rgb magneticColor
set label 2 sprintf("Mean I(deg) : %0.1f deg", ISTAT_mean)
set label 2 at graph fieldStatX, statMeanY tc rgb magneticColor
set label 3 sprintf("Max I(deg) : %0.1f deg", ISTAT_max)
set label 3 at graph fieldStatX, statMaxY tc rgb magneticColor
set label 4 sprintf("Min I(deg) : %0.1f deg", ISTAT_min)
set label 4 at graph fieldStatX, statMinY tc rgb magneticColor
set label 11 "Temperature statistics"
set label 11 at graph tempStatX, statTitleY tc rgb tempColor
set label 12 sprintf("Mean Temp(C) : %0.1f °C", TSTAT_mean)
set label 12 at graph tempStatX, statMeanY tc rgb tempColor
set label 13 sprintf("Max Temp(C) : %0.1f °C", TSTAT_max)
set label 13 at graph tempStatX, statMaxY tc rgb tempColor
set label 14 sprintf("Min Temp(C) : %0.1f °C", TSTAT_min)
set label 14 at graph tempStatX, statMinY tc rgb tempColor
plot fileData using 1:14 with lines linewidth 1.2 linecolor rgb magneticColor notitle, \
    fileData using 1:8 axes x1y2 with lines linewidth 1.0 linecolor rgb tempColor notitle

unset multiplot
set output
