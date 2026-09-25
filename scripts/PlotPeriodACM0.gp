#!/usr/bin/gnuplot -persist

set print "-"

basePath = system("sh -lc 'printf %s \"${MAGNETOMETER_BASE_PATH:-/home/pi/UKRAA_Magnetometer}\"'")
plotPeriod = system("sh -lc 'printf %s \"${MAGNETOMETER_PLOT_PERIOD:-week}\"'")
targetDate = system("sh -lc 'if [ -n \"${MAGNETOMETER_TARGET_DATE:-}\" ]; then printf %s \"$MAGNETOMETER_TARGET_DATE\"; else date -d yesterday +%Y-%m-%d; fi'")

if (plotPeriod eq "day") {
    if (plotFamily eq "XYZ") load basePath."/scripts/PlotDataXYZACM0.gp"
    if (plotFamily eq "HDZ") load basePath."/scripts/PlotDataHDZACM0.gp"
    if (plotFamily eq "BI") load basePath."/scripts/PlotDataBIACM0.gp"
    exit
}

periodDays = 0
if (plotPeriod eq "week") periodDays = 7
if (plotPeriod eq "month") periodDays = 30
if (plotPeriod eq "3month") periodDays = 90
if (plotPeriod eq "6month") periodDays = 183
if (plotPeriod eq "year") periodDays = 365
if (periodDays == 0) {
    print "PlotPeriodACM0.gp : FAILED - unknown period ".plotPeriod
    exit
}

summaryFile = basePath."/data/daily/summary.csv"
isMissing = system("/bin/bash ".basePath."/scripts/isMissing.sh ".summaryFile)
if (isMissing == 1) {
    print "PlotPeriodACM0.gp : FAILED - daily summary file missing"
    exit
}

startDate = system("sh -lc 'date -d \"".targetDate." - ".(periodDays - 1)." days\" +%Y-%m-%d'")
endDate = targetDate
plotYear = substr(targetDate, 1, 4)
plotYearMonth = substr(targetDate, 1, 7)
archiveDirectory = basePath."/plots/".plotPeriod."/".plotFamily."/".plotYear."/".plotYearMonth
archivePlot = archiveDirectory."/".targetDate.".png"
tempDirectory = basePath."/temp/periods/".plotPeriod
tempPlot = tempDirectory."/".plotFamily.".png"

system("sh -lc 'mkdir -p \"".archiveDirectory."\" \"".tempDirectory."\"'")

set terminal pngcairo background "#ffffff" enhanced font "DejaVuSansCondensed,10" size 960,960 rounded
set datafile separator ","
set xdata time
set timefmt "%Y-%m-%d %H:%M:%S"
if (plotPeriod eq "week" || plotPeriod eq "month") set format x "%d %b"
if (plotPeriod eq "3month" || plotPeriod eq "6month" || plotPeriod eq "year") set format x "%b\n%Y"
set xrange [startDate." 00:00:00":endDate." 23:59:59"]
set grid xtics ytics
set key outside above center
set lmargin 10
set rmargin 10
set ytics nomirror
set xlabel "Date (UTC)"

plotTitle = sprintf("%s magnetic field: %s to %s\nDaily aggregates from complete UTC days", plotFamily, startDate, endDate)
print system("date +'%Y-%m-%d %H:%M:%S'")." : PlotPeriod".plotFamily."ACM0.gp : Started ".plotPeriod." plot"

set output archivePlot
if (plotFamily eq "XYZ") {
    set multiplot layout 3,1 title plotTitle font ",12"
    set ylabel "X (nT)"
    plot summaryFile using 1:2 with lines linewidth 1.2 linecolor rgb "#0000ff" title "X"
    set ylabel "Y (nT)"
    plot summaryFile using 1:3 with lines linewidth 1.2 linecolor rgb "#008000" title "Y"
    set ylabel "Z (nT)"
    plot summaryFile using 1:4 with lines linewidth 1.2 linecolor rgb "#cc0000" title "Z"
    unset multiplot
}
if (plotFamily eq "HDZ") {
    set multiplot layout 3,1 title plotTitle font ",12"
    set ylabel "H (nT)"
    plot summaryFile using 1:7 with lines linewidth 1.2 linecolor rgb "#0000ff" title "H"
    set ylabel "D (deg)"
    plot summaryFile using 1:8 with lines linewidth 1.2 linecolor rgb "#008000" title "D"
    set ylabel "Z (nT)"
    plot summaryFile using 1:4 with lines linewidth 1.2 linecolor rgb "#cc0000" title "Z"
    unset multiplot
}
if (plotFamily eq "BI") {
    set multiplot layout 2,1 title plotTitle font ",12"
    set ylabel "B (nT)"
    plot summaryFile using 1:9 with lines linewidth 1.2 linecolor rgb "#0000ff" title "B"
    set ylabel "I (deg)"
    plot summaryFile using 1:10 with lines linewidth 1.2 linecolor rgb "#008000" title "I"
    unset multiplot
}
set output

system("sh -lc 'cp \"".archivePlot."\" \"".tempPlot."\"'")
print system("date +'%Y-%m-%d %H:%M:%S'")." : PlotPeriod".plotFamily."ACM0.gp : Completed ".plotPeriod." plot"