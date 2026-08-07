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
stats rollingData using 8 output prefix "TSTAT" nooutput

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
set format x "%H:%M"
set format y2 "%.1f"
set grid xtics ytics
unset key
set lmargin 10
set rmargin 10
set y2tics

startX = system("sh -lc 'head -n 1 \"".rollingData."\" | cut -d, -f1'")
endX = system("sh -lc 'tail -n 1 \"".rollingData."\" | cut -d, -f1'")
plotTitle = sprintf("Rolling magnetic field for the last 24 hours\nUpdated every 5 minutes\n%s UTC to %s UTC", startX, endX)

set xrange [startX:endX]
set output archivePlot
set multiplot layout 3,1 title plotTitle font ",12"

set ylabel "X (nT)"
set ylabel textcolor rgb magneticColor
set ytics textcolor rgb magneticColor
unset xlabel
set yrange [XSTAT_min - 200:XSTAT_max + 200]
set y2label "Temperature (C)"
set y2label textcolor rgb tempColor
set y2tics textcolor rgb tempColor
set y2range [tempRangeMin:tempRangeMax]
set label 1 "X field statistics"
set label 1 at graph fieldStatX, statTitleY tc rgb magneticColor
set label 2 sprintf("Mean X(nT) : %0.1f nT", XSTAT_mean)
set label 2 at graph fieldStatX, statMeanY tc rgb magneticColor
set label 3 sprintf("Max X(nT) : %0.1f nT", XSTAT_max)
set label 3 at graph fieldStatX, statMaxY tc rgb magneticColor
set label 4 sprintf("Min X(nT) : %0.1f nT", XSTAT_min)
set label 4 at graph fieldStatX, statMinY tc rgb magneticColor
set label 11 "Temperature statistics"
set label 11 at graph tempStatX, statTitleY tc rgb tempColor
set label 12 sprintf("Mean Temp(C) : %0.1f C", TSTAT_mean)
set label 12 at graph tempStatX, statMeanY tc rgb tempColor
set label 13 sprintf("Max Temp(C) : %0.1f C", TSTAT_max)
set label 13 at graph tempStatX, statMaxY tc rgb tempColor
set label 14 sprintf("Min Temp(C) : %0.1f C", TSTAT_min)
set label 14 at graph tempStatX, statMinY tc rgb tempColor
plot rollingData using 1:5 with lines linewidth 1.2 linecolor rgb magneticColor notitle, \
    rollingData using 1:8 axes x1y2 with lines linewidth 1.0 linecolor rgb tempColor notitle

set ylabel "Y (nT)"
set ylabel textcolor rgb magneticColor
set ytics textcolor rgb magneticColor
unset xlabel
set yrange [YSTAT_min - 200:YSTAT_max + 200]
set y2label "Temperature (C)"
set y2label textcolor rgb tempColor
set y2tics textcolor rgb tempColor
set y2range [tempRangeMin:tempRangeMax]
set label 1 "Y field statistics"
set label 1 at graph fieldStatX, statTitleY tc rgb magneticColor
set label 2 sprintf("Mean Y(nT) : %0.1f nT", YSTAT_mean)
set label 2 at graph fieldStatX, statMeanY tc rgb magneticColor
set label 3 sprintf("Max Y(nT) : %0.1f nT", YSTAT_max)
set label 3 at graph fieldStatX, statMaxY tc rgb magneticColor
set label 4 sprintf("Min Y(nT) : %0.1f nT", YSTAT_min)
set label 4 at graph fieldStatX, statMinY tc rgb magneticColor
set label 11 "Temperature statistics"
set label 11 at graph tempStatX, statTitleY tc rgb tempColor
set label 12 sprintf("Mean Temp(C) : %0.1f C", TSTAT_mean)
set label 12 at graph tempStatX, statMeanY tc rgb tempColor
set label 13 sprintf("Max Temp(C) : %0.1f C", TSTAT_max)
set label 13 at graph tempStatX, statMaxY tc rgb tempColor
set label 14 sprintf("Min Temp(C) : %0.1f C", TSTAT_min)
set label 14 at graph tempStatX, statMinY tc rgb tempColor
plot rollingData using 1:6 with lines linewidth 1.2 linecolor rgb magneticColor notitle, \
    rollingData using 1:8 axes x1y2 with lines linewidth 1.0 linecolor rgb tempColor notitle

set ylabel "Z (nT)"
set ylabel textcolor rgb magneticColor
set ytics textcolor rgb magneticColor
set xlabel "Time (UTC)"
set yrange [ZSTAT_min - 200:ZSTAT_max + 200]
set y2label "Temperature (C)"
set y2label textcolor rgb tempColor
set y2tics textcolor rgb tempColor
set y2range [tempRangeMin:tempRangeMax]
set label 1 "Z field statistics"
set label 1 at graph fieldStatX, statTitleY tc rgb magneticColor
set label 2 sprintf("Mean Z(nT) : %0.1f nT", ZSTAT_mean)
set label 2 at graph fieldStatX, statMeanY tc rgb magneticColor
set label 3 sprintf("Max Z(nT) : %0.1f nT", ZSTAT_max)
set label 3 at graph fieldStatX, statMaxY tc rgb magneticColor
set label 4 sprintf("Min Z(nT) : %0.1f nT", ZSTAT_min)
set label 4 at graph fieldStatX, statMinY tc rgb magneticColor
set label 11 "Temperature statistics"
set label 11 at graph tempStatX, statTitleY tc rgb tempColor
set label 12 sprintf("Mean Temp(C) : %0.1f C", TSTAT_mean)
set label 12 at graph tempStatX, statMeanY tc rgb tempColor
set label 13 sprintf("Max Temp(C) : %0.1f C", TSTAT_max)
set label 13 at graph tempStatX, statMaxY tc rgb tempColor
set label 14 sprintf("Min Temp(C) : %0.1f C", TSTAT_min)
set label 14 at graph tempStatX, statMinY tc rgb tempColor
plot rollingData using 1:7 with lines linewidth 1.2 linecolor rgb magneticColor notitle, \
    rollingData using 1:8 axes x1y2 with lines linewidth 1.0 linecolor rgb tempColor notitle

unset multiplot
set output


set output tempPlot
set multiplot layout 3,1 title plotTitle font ",12"

set ylabel "X (nT)"
set ylabel textcolor rgb magneticColor
set ytics textcolor rgb magneticColor
unset xlabel
set yrange [XSTAT_min - 200:XSTAT_max + 200]
set y2label "Temperature (C)"
set y2label textcolor rgb tempColor
set y2tics textcolor rgb tempColor
set y2range [tempRangeMin:tempRangeMax]
set label 1 "X field statistics"
set label 1 at graph fieldStatX, statTitleY tc rgb magneticColor
set label 2 sprintf("Mean X(nT) : %0.1f nT", XSTAT_mean)
set label 2 at graph fieldStatX, statMeanY tc rgb magneticColor
set label 3 sprintf("Max X(nT) : %0.1f nT", XSTAT_max)
set label 3 at graph fieldStatX, statMaxY tc rgb magneticColor
set label 4 sprintf("Min X(nT) : %0.1f nT", XSTAT_min)
set label 4 at graph fieldStatX, statMinY tc rgb magneticColor
set label 11 "Temperature statistics"
set label 11 at graph tempStatX, statTitleY tc rgb tempColor
set label 12 sprintf("Mean Temp(C) : %0.1f C", TSTAT_mean)
set label 12 at graph tempStatX, statMeanY tc rgb tempColor
set label 13 sprintf("Max Temp(C) : %0.1f C", TSTAT_max)
set label 13 at graph tempStatX, statMaxY tc rgb tempColor
set label 14 sprintf("Min Temp(C) : %0.1f C", TSTAT_min)
set label 14 at graph tempStatX, statMinY tc rgb tempColor
plot rollingData using 1:5 with lines linewidth 1.2 linecolor rgb magneticColor notitle, \
    rollingData using 1:8 axes x1y2 with lines linewidth 1.0 linecolor rgb tempColor notitle

set ylabel "Y (nT)"
set ylabel textcolor rgb magneticColor
set ytics textcolor rgb magneticColor
unset xlabel
set yrange [YSTAT_min - 200:YSTAT_max + 200]
set y2label "Temperature (C)"
set y2label textcolor rgb tempColor
set y2tics textcolor rgb tempColor
set y2range [tempRangeMin:tempRangeMax]
set label 1 "Y field statistics"
set label 1 at graph fieldStatX, statTitleY tc rgb magneticColor
set label 2 sprintf("Mean Y(nT) : %0.1f nT", YSTAT_mean)
set label 2 at graph fieldStatX, statMeanY tc rgb magneticColor
set label 3 sprintf("Max Y(nT) : %0.1f nT", YSTAT_max)
set label 3 at graph fieldStatX, statMaxY tc rgb magneticColor
set label 4 sprintf("Min Y(nT) : %0.1f nT", YSTAT_min)
set label 4 at graph fieldStatX, statMinY tc rgb magneticColor
set label 11 "Temperature statistics"
set label 11 at graph tempStatX, statTitleY tc rgb tempColor
set label 12 sprintf("Mean Temp(C) : %0.1f C", TSTAT_mean)
set label 12 at graph tempStatX, statMeanY tc rgb tempColor
set label 13 sprintf("Max Temp(C) : %0.1f C", TSTAT_max)
set label 13 at graph tempStatX, statMaxY tc rgb tempColor
set label 14 sprintf("Min Temp(C) : %0.1f C", TSTAT_min)
set label 14 at graph tempStatX, statMinY tc rgb tempColor
plot rollingData using 1:6 with lines linewidth 1.2 linecolor rgb magneticColor notitle, \
    rollingData using 1:8 axes x1y2 with lines linewidth 1.0 linecolor rgb tempColor notitle

set ylabel "Z (nT)"
set ylabel textcolor rgb magneticColor
set ytics textcolor rgb magneticColor
set xlabel "Time (UTC)"
set yrange [ZSTAT_min - 200:ZSTAT_max + 200]
set y2label "Temperature (C)"
set y2label textcolor rgb tempColor
set y2tics textcolor rgb tempColor
set y2range [tempRangeMin:tempRangeMax]
set label 1 "Z field statistics"
set label 1 at graph fieldStatX, statTitleY tc rgb magneticColor
set label 2 sprintf("Mean Z(nT) : %0.1f nT", ZSTAT_mean)
set label 2 at graph fieldStatX, statMeanY tc rgb magneticColor
set label 3 sprintf("Max Z(nT) : %0.1f nT", ZSTAT_max)
set label 3 at graph fieldStatX, statMaxY tc rgb magneticColor
set label 4 sprintf("Min Z(nT) : %0.1f nT", ZSTAT_min)
set label 4 at graph fieldStatX, statMinY tc rgb magneticColor
set label 11 "Temperature statistics"
set label 11 at graph tempStatX, statTitleY tc rgb tempColor
set label 12 sprintf("Mean Temp(C) : %0.1f C", TSTAT_mean)
set label 12 at graph tempStatX, statMeanY tc rgb tempColor
set label 13 sprintf("Max Temp(C) : %0.1f C", TSTAT_max)
set label 13 at graph tempStatX, statMaxY tc rgb tempColor
set label 14 sprintf("Min Temp(C) : %0.1f C", TSTAT_min)
set label 14 at graph tempStatX, statMinY tc rgb tempColor
plot rollingData using 1:7 with lines linewidth 1.2 linecolor rgb magneticColor notitle, \
    rollingData using 1:8 axes x1y2 with lines linewidth 1.0 linecolor rgb tempColor notitle

unset multiplot
set output