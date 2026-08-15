#!/usr/bin/gnuplot -persist

reset

basePath = system("sh -lc 'printf %s \"${MAGNETOMETER_BASE_PATH:-/home/pi/UKRAA_Magnetometer}\"'")
windowKey = system("sh -lc 'printf %s \"${MAGNETOMETER_HISTORY_WINDOW:-7d}\"'")
fileData = basePath."/data/history/".windowKey."/history.csv"

is_missing = system("sudo /bin/bash ".basePath."/scripts/isMissing.sh ".fileData)
if (is_missing == 1) {
    print system("date +'%Y-%m-%d %H:%M:%S'") \
          ." : PlotHistoryBIACM0.gp     : FAILED - data file missing for window " \
          .windowKey
    exit
}

dateTag = system("date -d yesterday +'%Y-%m-%d'")
archivePlot = basePath."/plots/history/".windowKey."/".dateTag."_BI_plot.png"
tempPlot = basePath."/temp/history/".windowKey."/BI.png"

system("sh -lc 'mkdir -p \"".basePath."/plots/history/".windowKey."\" \"".basePath."/temp/history/".windowKey."\"'")

set terminal pngcairo \
             background "#ffffff" \
             enhanced \
             font "DejaVuSansCondensed,10" \
             size 960,760 \
             rounded

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
set format x "%m-%d"
set format y2 "%.1f"
set grid xtics ytics
unset key
set lmargin 10
set rmargin 10
set y2tics

startX = system("sh -lc 'head -n 1 \"".fileData."\" | cut -d, -f1'")
endX = system("sh -lc 'tail -n 1 \"".fileData."\" | cut -d, -f1'")
plotTitle = sprintf("BI magnetic field history (%s)\n%s UTC to %s UTC", windowKey, startX, endX)

set xrange [startX:endX]

print system("date +'%Y-%m-%d %H:%M:%S'") \
      ." : PlotHistoryBIACM0.gp     : Started BI history plot for window " \
      .windowKey

set output archivePlot
set multiplot layout 2,1 title plotTitle font ",12"

set ylabel "B (nT)"
set ylabel textcolor rgb magneticColor
set ytics textcolor rgb magneticColor
unset xlabel
set yrange [BSTAT_min - 200:BSTAT_max + 200]
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
set xlabel "Date (UTC)"
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
set yrange [BSTAT_min - 200:BSTAT_max + 200]
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
set xlabel "Date (UTC)"
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

print system("date +'%Y-%m-%d %H:%M:%S'") \
      ." : PlotHistoryBIACM0.gp     : Completed BI history plot for window " \
      .windowKey
