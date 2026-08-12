#!/usr/bin/gnuplot -persist
#
#    
#    	G N U P L O T
#    	Version 5.2 patchlevel 6    last modified 2019-01-01 
#    
#    	Copyright (C) 1986-1993, 1998, 2004, 2007-2018
#    	Thomas Williams, Colin Kelley and many others
#    
#    	gnuplot home:     http://www.gnuplot.info
#    	faq, bugs, etc:   type "help FAQ"
#    	immediate help:   type "help"  (plot window: hit 'h')

# Reset gnuplot variables
reset

# Set terminal 
set terminal pngcairo \
             background "#ffffff"\
             enhanced \
             font "DejaVuSansCondensed, 10"\
             fontscale 1.0\
             size 960,960\
             rounded

# Set print to <stdout>
set print "-"

basePath = system("sh -lc 'printf %s \"${MAGNETOMETER_BASE_PATH:-/home/pi/UKRAA_Magnetometer}\"'")
targetDate = system("sh -lc 'if [ -n \"${MAGNETOMETER_TARGET_DATE:-}\" ]; then printf %s \"$MAGNETOMETER_TARGET_DATE\"; else date -d yesterday +%Y-%m-%d; fi'")
targetDatePretty = system("sh -lc 'date -d \"".targetDate."\" +\"%A %d %B %Y\"'")
nextDate = system("sh -lc 'date -d \"".targetDate." +1 day\" +%Y-%m-%d'")
archiveEnabled = int(real(system("sh -lc 'printf %s \"${MAGNETOMETER_ACTIVITY_PLOT_ARCHIVE:-1}\"'")))

thresholdValues = system("sh -lc 'MAGNETOMETER_BASE_PATH=\"".basePath."\" /usr/bin/python3 \"".basePath."/scripts/GetAlertThresholdsACM0.py\"'")
yellowThreshold = real(word(thresholdValues, 1))
amberThreshold = real(word(thresholdValues, 2))
redThreshold = real(word(thresholdValues, 3))

# print to log file
print system("date +'%Y-%m-%d %H:%M:%S'")\
      ." : PlotDataActivityACM0.gp  : Started Activity plot for "\
      .targetDate

# Path to data file for graphing
FileData = basePath\
           ."/data/processed/hour/"\
           .substr(targetDate, 1, 4)\
           ."/"\
           .substr(targetDate, 1, 7)\
           ."/"\
           .targetDate\
           .".csv"

# check if FileData exists - 0=exists, 1=doesn't exist, if doesn't exist then exit, with message
is_missing = system("/bin/bash ".basePath."/scripts/isMissing.sh ".FileData)
if (is_missing == 1) \
           {
           print system("date +'%Y-%m-%d %H:%M:%S'")\
                 ." : PlotDataActivityACM0.gp  : FAILED - data file missing, so..."; 
           print system("date +'%Y-%m-%d %H:%M:%S'")\
                 ." : PlotDataActivityACM0.gp  : **FAILED** to complete Activity plot for "\
                 .targetDate
           exit
           }

# FileData exists - good to continue...

# Set separator to ","
set datafile separator ","

# undertake stats before setting timeformat and xdata
stats FileData using 9 output prefix "ACTIVITYdata" nooutput

# Start of X axis time
StartXaxis = targetDate." 00:00:00"

# End of X axis time
EndXaxis = nextDate." 00:00:00"

# setting output path to include data stamp
# Path to directory to store file

pathPlot1 = basePath."/plots/Activity/"\
             .targetDate\
             .".png"
pathTemp1 = basePath."/temp/Activity.png"

# Title for graph
dateTag = system("date -d yesterday +'%Y-%m-%d'")
startX = system("sh -lc 'head -n 1 \"".FileData."\" | cut -d, -f1'")
endX = system("sh -lc 'tail -n 1 \"".FileData."\" | cut -d, -f1'")
GraphTitle1 = sprintf("Hourly geomagnetic activity for %s\nGraph is updated every day at 9.30am\n%s UTC to %s UTC", dateTag, startX, endX)


# Set data types
set xdata time

# Set format types
set format x "%H:%M" timedate
set format y "%.1f" 
set format y2 "%.1f" 
set timefmt "%Y-%m-%d %H:%M:%S"

# Set grid format
set grid xtics nomxtics ytics nomytics noztics nomztics nortics nomrtics \
         nox2tics nomx2tics noy2tics nomy2tics nocbtics nomcbtics
set grid layerdefault linetype 0 linecolor 0 linewidth 0.500 dashtype solid,\
         linetype 0 linecolor 0 linewidth 0.500 dashtype solid

# Set Legend (Key) above plot
set key outside above center
set key samplen 10
#set key title GraphTitle
set key nobox

# X-axis tics
set mxtics 2.0
set xtics border out scale 1,0.5 nomirror norotate  autojustify
set xtics norangelimit 7200
set xtics textcolor rgb "black"
set xtics font ",8"

# Y-axis tics
set mytics 2.0
set ytics border out scale 1,0.5 nomirror norotate  autojustify
set ytics norangelimit autofreq
set ytics textcolor rgb "black"

# X-axis label and ranges
set xlabel "Time (UTC)" 
set xlabel textcolor rgb "black" norotate
set xrange [ StartXaxis : EndXaxis ] noreverse nowriteback

##### Plot command # Activity(nT)

# Y-axis labels and ranges
set ylabel "Activity (nT)" 
set ylabel textcolor rgb "black" rotate
topRange = (ACTIVITYdata_max > redThreshold) ? (ACTIVITYdata_max + 20) : (redThreshold + 20)
set yrange [ 0 : topRange ] noreverse nowriteback

# set STATS labels on graph
set label 1 sprintf("Mean Activity(nT) : %0.1f nT", ACTIVITYdata_mean)
set label 1 at graph 0.02, 0.95 tc default
set label 2 sprintf("Max Activity(nT) : %0.1f nT", ACTIVITYdata_max)
set label 2 at graph 0.02, 0.90 tc default
set label 3 sprintf("Min Activity(nT) : %0.1f nT", ACTIVITYdata_min)
set label 3 at graph 0.02, 0.85 tc default

# set threshold lines for activity
set arrow 1 from graph 0, first yellowThreshold to graph 1, first yellowThreshold nohead lt rgb 0xFFFF00 lw 2
set arrow 2 from graph 0, first amberThreshold to graph 1, first amberThreshold nohead lt rgb 0xFF8503 lw 2
set arrow 3 from graph 0, first redThreshold to graph 1, first redThreshold nohead lt rgb 0xFF0000 lw 2

# set bar colour based on hourly activity thresholds
my_colour(val) = (val < yellowThreshold) ? 0x00FF00 : (val <= amberThreshold) ? 0xFFFF00 : (val <= redThreshold) ? 0xFF8503 : 0xFF0000

# Use fixed 1-hour bars centered on :30.
set boxwidth 3600 absolute
set style fill solid 1.0 border linetype -1

GraphTitle = GraphTitle1
set key title GraphTitle
if (archiveEnabled == 1) {
      set output pathPlot1
      plot FileData using 1:9:(my_colour($9)) \
                                    with boxes \
                                    fillstyle solid 1.0 noborder \
                                    notitle \
                                    linecolor rgb variable, \
             FileData using 1:9 \
                                    with boxes \
                                    fillstyle empty border rgb "black" \
                                    notitle \
                                    linecolor rgb "black"
      set output
}

set output pathTemp1
plot FileData using 1:9:(my_colour($9)) \
                              with boxes \
                              fillstyle solid 1.0 noborder \
                              notitle \
                              linecolor rgb variable, \
       FileData using 1:9 \
                              with boxes \
                              fillstyle empty border rgb "black" \
                              notitle \
                              linecolor rgb "black"

# This is important because it closes our output file.
set output

# print to log file
print system("date +'%Y-%m-%d %H:%M:%S'")\
      ." : PlotDataActivityACM0.gp  : Completed Activity plot for "\
      .targetDate

# EOF