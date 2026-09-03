#!/usr/bin/gnuplot -persist

reset

# Send print output to stdout so progress lines land in the main log, not log-error.txt
set print "-"

basePath = system("sh -lc 'printf %s \"${MAGNETOMETER_BASE_PATH:-/home/pi/UKRAA_Magnetometer}\"'")
pathData = basePath."/data/minute"

fileData = pathData."/" \
           .system("date -d yesterday +'%Y'") \
           ."/" \
           .system("date -d yesterday +'%Y-%m'") \
           ."/" \
           .system("date -d yesterday +'%Y-%m-%d'") \
           .".csv"

is_missing = system("sudo /bin/bash ".basePath."/scripts/isMissing.sh ".fileData)
if (is_missing == 1) {
    print system("date +'%Y-%m-%d %H:%M:%S'") \
          ." : PlotDataHDZACM0.gp        : FAILED - data file missing"
    exit
}

dateTag = system("date -d yesterday +'%Y-%m-%d'")
plotYear = substr(dateTag, 1, 4)
plotYearMonth = substr(dateTag, 1, 7)
plotMonthDir = basePath."/plots/HDZ/".plotYear."/".plotYearMonth
archivePlot = plotMonthDir."/".dateTag.".png"
tempPlot = basePath."/temp/HDZ.png"

# mkdir -p plus 0/1 flag so a fresh year/month archive folder can be logged, matching the Python processors
dirCreated = system("sh -lc 'if [ -d \"".plotMonthDir."\" ]; then echo 0; else mkdir -p \"".plotMonthDir."\"; echo 1; fi'")
if (dirCreated == 1) {
    print system("date +'%Y-%m-%d %H:%M:%S'") \
          ." : PlotDataHDZACM0.gp        : New directory created : ".plotMonthDir
}
system("sh -lc 'mkdir -p \"".basePath."/temp\"'")

set terminal pngcairo \
             background "#ffffff" \
             enhanced \
             font "DejaVuSansCondensed,10" \
             size 960,960 \
             rounded

set datafile separator ","

stats fileData using 10 output prefix "HSTAT" nooutput
stats fileData using 11 output prefix "DSTAT" nooutput
stats fileData using 12 output prefix "ZSTAT" nooutput
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
set format x "%H:%M"
set format y2 "%.1f"
set grid xtics ytics
unset key
set lmargin 10
set rmargin 10
set y2tics

startX = system("sh -lc 'head -n 1 \"".fileData."\" | cut -d, -f1'")
endX = system("sh -lc 'tail -n 1 \"".fileData."\" | cut -d, -f1'")
plotTitle = sprintf("HDZ magnetic field for %s\nGraph is updated every day at 9.30am\n%s UTC to %s UTC", dateTag, startX, endX)

set xrange [startX:endX]

print system("date +'%Y-%m-%d %H:%M:%S'") \
      ." : PlotDataHDZACM0.gp        : Started HDZ plot for " \
      .dateTag

set output archivePlot
set multiplot layout 3,1 title plotTitle font ",12"

set ylabel "H (nT)"
set ylabel textcolor rgb magneticColor
set ytics textcolor rgb magneticColor
unset xlabel
set yrange [HSTAT_min - 10:HSTAT_max + 10]
set y2label "Temperature (°C)"
set y2label textcolor rgb tempColor
set y2tics textcolor rgb tempColor
set y2range [tempRangeMin:tempRangeMax]
set label 1 "H field statistics"
set label 1 at graph fieldStatX, statTitleY tc rgb magneticColor
set label 2 sprintf("Mean H(nT) : %0.1f nT", HSTAT_mean)
set label 2 at graph fieldStatX, statMeanY tc rgb magneticColor
set label 3 sprintf("Max H(nT) : %0.1f nT", HSTAT_max)
set label 3 at graph fieldStatX, statMaxY tc rgb magneticColor
set label 4 sprintf("Min H(nT) : %0.1f nT", HSTAT_min)
set label 4 at graph fieldStatX, statMinY tc rgb magneticColor
set label 11 "Temperature statistics"
set label 11 at graph tempStatX, statTitleY tc rgb tempColor
set label 12 sprintf("Mean Temp(C) : %0.1f °C", TSTAT_mean)
set label 12 at graph tempStatX, statMeanY tc rgb tempColor
set label 13 sprintf("Max Temp(C) : %0.1f °C", TSTAT_max)
set label 13 at graph tempStatX, statMaxY tc rgb tempColor
set label 14 sprintf("Min Temp(C) : %0.1f °C", TSTAT_min)
set label 14 at graph tempStatX, statMinY tc rgb tempColor
plot fileData using 1:10 with lines linewidth 1.2 linecolor rgb magneticColor notitle, \
    fileData using 1:8 axes x1y2 with lines linewidth 1.0 linecolor rgb tempColor notitle

set ylabel "D (deg)"
set ylabel textcolor rgb magneticColor
set ytics textcolor rgb magneticColor
unset xlabel
set yrange [DSTAT_min - 0.5:DSTAT_max + 0.5]
set y2label "Temperature (°C)"
set y2label textcolor rgb tempColor
set y2tics textcolor rgb tempColor
set y2range [tempRangeMin:tempRangeMax]
set label 1 "D angle statistics"
set label 1 at graph fieldStatX, statTitleY tc rgb magneticColor
set label 2 sprintf("Mean D(deg) : %0.1f deg", DSTAT_mean)
set label 2 at graph fieldStatX, statMeanY tc rgb magneticColor
set label 3 sprintf("Max D(deg) : %0.1f deg", DSTAT_max)
set label 3 at graph fieldStatX, statMaxY tc rgb magneticColor
set label 4 sprintf("Min D(deg) : %0.1f deg", DSTAT_min)
set label 4 at graph fieldStatX, statMinY tc rgb magneticColor
set label 11 "Temperature statistics"
set label 11 at graph tempStatX, statTitleY tc rgb tempColor
set label 12 sprintf("Mean Temp(C) : %0.1f °C", TSTAT_mean)
set label 12 at graph tempStatX, statMeanY tc rgb tempColor
set label 13 sprintf("Max Temp(C) : %0.1f °C", TSTAT_max)
set label 13 at graph tempStatX, statMaxY tc rgb tempColor
set label 14 sprintf("Min Temp(C) : %0.1f °C", TSTAT_min)
set label 14 at graph tempStatX, statMinY tc rgb tempColor
plot fileData using 1:11 with lines linewidth 1.2 linecolor rgb magneticColor notitle, \
    fileData using 1:8 axes x1y2 with lines linewidth 1.0 linecolor rgb tempColor notitle

set ylabel "Z (nT)"
set ylabel textcolor rgb magneticColor
set ytics textcolor rgb magneticColor
set xlabel "Time (UTC)"
set yrange [ZSTAT_min - 10:ZSTAT_max + 10]
set y2label "Temperature (°C)"
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
set label 12 sprintf("Mean Temp(C) : %0.1f °C", TSTAT_mean)
set label 12 at graph tempStatX, statMeanY tc rgb tempColor
set label 13 sprintf("Max Temp(C) : %0.1f °C", TSTAT_max)
set label 13 at graph tempStatX, statMaxY tc rgb tempColor
set label 14 sprintf("Min Temp(C) : %0.1f °C", TSTAT_min)
set label 14 at graph tempStatX, statMinY tc rgb tempColor
plot fileData using 1:12 with lines linewidth 1.2 linecolor rgb magneticColor notitle, \
    fileData using 1:8 axes x1y2 with lines linewidth 1.0 linecolor rgb tempColor notitle

unset multiplot
set output

set output tempPlot
set multiplot layout 3,1 title plotTitle font ",12"

set ylabel "H (nT)"
set ylabel textcolor rgb magneticColor
set ytics textcolor rgb magneticColor
unset xlabel
set yrange [HSTAT_min - 10:HSTAT_max + 10]
set y2label "Temperature (°C)"
set y2label textcolor rgb tempColor
set y2tics textcolor rgb tempColor
set y2range [tempRangeMin:tempRangeMax]
set label 1 "H field statistics"
set label 1 at graph fieldStatX, statTitleY tc rgb magneticColor
set label 2 sprintf("Mean H(nT) : %0.1f nT", HSTAT_mean)
set label 2 at graph fieldStatX, statMeanY tc rgb magneticColor
set label 3 sprintf("Max H(nT) : %0.1f nT", HSTAT_max)
set label 3 at graph fieldStatX, statMaxY tc rgb magneticColor
set label 4 sprintf("Min H(nT) : %0.1f nT", HSTAT_min)
set label 4 at graph fieldStatX, statMinY tc rgb magneticColor
set label 11 "Temperature statistics"
set label 11 at graph tempStatX, statTitleY tc rgb tempColor
set label 12 sprintf("Mean Temp(C) : %0.1f °C", TSTAT_mean)
set label 12 at graph tempStatX, statMeanY tc rgb tempColor
set label 13 sprintf("Max Temp(C) : %0.1f °C", TSTAT_max)
set label 13 at graph tempStatX, statMaxY tc rgb tempColor
set label 14 sprintf("Min Temp(C) : %0.1f °C", TSTAT_min)
set label 14 at graph tempStatX, statMinY tc rgb tempColor
plot fileData using 1:10 with lines linewidth 1.2 linecolor rgb magneticColor notitle, \
    fileData using 1:8 axes x1y2 with lines linewidth 1.0 linecolor rgb tempColor notitle

set ylabel "D (deg)"
set ylabel textcolor rgb magneticColor
set ytics textcolor rgb magneticColor
unset xlabel
set yrange [DSTAT_min - 0.5:DSTAT_max + 0.5]
set y2label "Temperature (°C)"
set y2label textcolor rgb tempColor
set y2tics textcolor rgb tempColor
set y2range [tempRangeMin:tempRangeMax]
set label 1 "D angle statistics"
set label 1 at graph fieldStatX, statTitleY tc rgb magneticColor
set label 2 sprintf("Mean D(deg) : %0.1f deg", DSTAT_mean)
set label 2 at graph fieldStatX, statMeanY tc rgb magneticColor
set label 3 sprintf("Max D(deg) : %0.1f deg", DSTAT_max)
set label 3 at graph fieldStatX, statMaxY tc rgb magneticColor
set label 4 sprintf("Min D(deg) : %0.1f deg", DSTAT_min)
set label 4 at graph fieldStatX, statMinY tc rgb magneticColor
set label 11 "Temperature statistics"
set label 11 at graph tempStatX, statTitleY tc rgb tempColor
set label 12 sprintf("Mean Temp(C) : %0.1f °C", TSTAT_mean)
set label 12 at graph tempStatX, statMeanY tc rgb tempColor
set label 13 sprintf("Max Temp(C) : %0.1f °C", TSTAT_max)
set label 13 at graph tempStatX, statMaxY tc rgb tempColor
set label 14 sprintf("Min Temp(C) : %0.1f °C", TSTAT_min)
set label 14 at graph tempStatX, statMinY tc rgb tempColor
plot fileData using 1:11 with lines linewidth 1.2 linecolor rgb magneticColor notitle, \
    fileData using 1:8 axes x1y2 with lines linewidth 1.0 linecolor rgb tempColor notitle

set ylabel "Z (nT)"
set ylabel textcolor rgb magneticColor
set ytics textcolor rgb magneticColor
set xlabel "Time (UTC)"
set yrange [ZSTAT_min - 10:ZSTAT_max + 10]
set y2label "Temperature (°C)"
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
set label 12 sprintf("Mean Temp(C) : %0.1f °C", TSTAT_mean)
set label 12 at graph tempStatX, statMeanY tc rgb tempColor
set label 13 sprintf("Max Temp(C) : %0.1f °C", TSTAT_max)
set label 13 at graph tempStatX, statMaxY tc rgb tempColor
set label 14 sprintf("Min Temp(C) : %0.1f °C", TSTAT_min)
set label 14 at graph tempStatX, statMinY tc rgb tempColor
plot fileData using 1:12 with lines linewidth 1.2 linecolor rgb magneticColor notitle, \
    fileData using 1:8 axes x1y2 with lines linewidth 1.0 linecolor rgb tempColor notitle

unset multiplot
set output

print system("date +'%Y-%m-%d %H:%M:%S'") \
      ." : PlotDataHDZACM0.gp        : Completed HDZ plot for " \
      .dateTag
