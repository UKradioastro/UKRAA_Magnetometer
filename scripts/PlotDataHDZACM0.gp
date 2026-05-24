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
             size 640,540\
             rounded

# Set print to <stdout>
set print "-"

# print to log file
print "PlotDataHDZACM0.gp    : "\
       .system("date +'%Y-%m-%d %H:%M:%S'")\
       ." : Started HDZ plot for "\
       .system("date -d yesterday +'%Y-%m-%d'")

# Set up data paths
pathData = "/home/pi/UKRAA_Magnetometer/data/processed"

# Path to each data file for graphing
FileData = pathData\
           ."/"\
           .system("date -d yesterday +'%Y'")\
           ."/"\
           .system("date -d yesterday +'%Y-%m'")\
           ."/"\
           .system("date -d yesterday +'%Y-%m-%d'")\
           .".csv"

# check if FileData exists - 0=exists, 1=doesn't exist, if doesn't exist then exit, with message
is_missing = system("sudo /bin/bash /home/pi/UKRAA_Magnetometer/scripts/isMissing.sh ".FileData)
if (is_missing == 1) \
           {
           print "PlotDataHDZACM0.gp    : "\
                  .system("date +'%Y/%M/%d %H:%M:%S'")\
                  ." : data file missing, so..."; 
           print "PlotDataHDZACM0.gp    : "\
                  .system("date +'%Y/%M/%d %H:%M:%S'")\
                  ." : **FAILED** to complete HDZ plot for "\
                  .system("date -d yesterday +'%Y-%m-%d'")
           exit
           }

# FileData exists - good to continue...

# Set separator to ","
set datafile separator ","

# undertake stats before setting timeformat and xdata
stats FileData using 11 output prefix "HTdata" nooutput
stats FileData using 12 output prefix "DTdata" nooutput
stats FileData using 13 output prefix "ZTdata" nooutput

# date to be processed
date = system("date -d yesterday +'%Y-%m-%d'")

# Start of X axis time
StartXaxis = system("date -d '-1 day' +'%Y-%m-%d'")." 00:00:00"

# End of X axis time
EndXaxis = system("date +'%Y-%m-%d'")." 00:00:00"

# setting output path to include data stamp
# Path to directory to store file
# X plot (nT)
pathPlot1 = "/home/pi/UKRAA_Magnetometer/plots/HDZ/"\
             .date\
             ."_H_plot.png"
pathTemp1 = "/home/pi/UKRAA_Magnetometer/temp/H.png"
# Y plot (nT)
pathPlot2 = "/home/pi/UKRAA_Magnetometer/plots/HDZ/"\
             .date\
             ."_D_plot.png"
pathTemp2 = "/home/pi/UKRAA_Magnetometer/temp/D.png"
# Z plot (nT)
pathPlot3 = "/home/pi/UKRAA_Magnetometer/plots/HDZ/"\
             .date\
             ."_Z_plot.png"
pathTemp3 = "/home/pi/UKRAA_Magnetometer/temp/Z.png"

# Title for graph
# H plot (nT)
GraphTitle1 = "H magnetic field data for "\
               .system("date -d yesterday +'%A %d %B %Y'")\
               ."\n Graph is updated every day at 9.30am \n"
# D plot (deg
GraphTitle2 = "D magnetic angle data for "\
               .system("date -d yesterday +'%A %d %B %Y'")\
               ."\n Graph is updated every day at 9.30am \n"
# Z plot (nT)
GraphTitle3 = "Z magnetic field data for "\
               .system("date -d yesterday +'%A %d %B %Y'")\
               ."\n Graph is updated every day at 9.30am \n"

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
set ytics textcolor rgb "dark-violet"

# X-axis label and ranges
set xlabel "Time (UTC)" 
set xlabel textcolor rgb "black" norotate
set xrange [ StartXaxis : EndXaxis ] noreverse nowriteback

##### Plot command # H(nT)

# Y-axis labels and ranges
set ylabel "H (nT)" 
set ylabel textcolor rgb "dark-violet" rotate
set yrange [ (HTdata_min - 500) : (HTdata_max + 500) ] noreverse nowriteback

# set STATS labels on graph
set label 1 sprintf("Mean H(nT) : %0.1f nT", HTdata_mean)
set label 1 at graph 0.02, 0.95 tc default
set label 2 sprintf("Max H(nT) : %0.1f nT", HTdata_max)
set label 2 at graph 0.02, 0.90 tc default
set label 3 sprintf("Min H(nT) : %0.1f nT", HTdata_min)
set label 3 at graph 0.02, 0.85 tc default

GraphTitle = GraphTitle1
set key title GraphTitle
set output pathPlot1
plot FileData using 1:11 \
                    linetype 1 \
                    linewidth 1 \
                    linecolor rgb "#0000FF" \
                    title "H magnetic field variation" \
                    with lines

# Replot to terminal and create .png image with data tag for future upload to web page
set output pathTemp1
replot
# end replot

###### Plot command # D(deg)

# Y-axis labels and ranges
set ylabel "D (deg)" 
set ylabel textcolor rgb "dark-violet" rotate
set yrange [ (DTdata_min - 5) : (DTdata_max + 5) ] noreverse nowriteback

# set STATS labels on graph
set label 1 sprintf("Mean D(deg) : %0.1f deg", DTdata_mean)
set label 1 at graph 0.02, 0.95 tc default
set label 2 sprintf("Max D(deg) : %0.1f deg", DTdata_max)
set label 2 at graph 0.02, 0.90 tc default
set label 3 sprintf("Min D(deg) : %0.1f deg", DTdata_min)
set label 3 at graph 0.02, 0.85 tc default

GraphTitle = GraphTitle2
set key title GraphTitle
set output pathPlot2
plot FileData using 1:12 \
                    linetype 1 \
                    linewidth 1 \
                    linecolor rgb "#FF0000" \
                    title "D magnetic angle variation" \
                    with lines

# Replot to terminal and create .png image with data tag for future upload to web page
set output pathTemp2
replot
# end replot

##### Plot command # Z(nT)

# Y-axis labels and ranges
set ylabel "Z (nT)" 
set ylabel textcolor rgb "dark-violet" rotate
set yrange [ (ZTdata_min - 500) : (ZTdata_max + 500) ] noreverse nowriteback

# set STATS labels on graph
set label 1 sprintf("Mean Z(nT) : %0.1f nT", ZTdata_mean)
set label 1 at graph 0.02, 0.95 tc default
set label 2 sprintf("Max Z(nT) : %0.1f nT", ZTdata_max)
set label 2 at graph 0.02, 0.90 tc default
set label 3 sprintf("Min Z(nT) : %0.1f nT", ZTdata_min)
set label 3 at graph 0.02, 0.85 tc default

GraphTitle = GraphTitle3
set key title GraphTitle
set output pathPlot3
plot FileData using 1:13 \
                    linetype 1 \
                    linewidth 1 \
                    linecolor rgb "#00FF00" \
                    title "Z magnetic field variation" \
                    with lines

# Replot to terminal and create .png image with data tag for future upload to web page
set output pathTemp3
replot
# end replot

# This is important because it closes our output file.
set output

# print to log file
print "PlotDataHDZACM0.gp    : "\
       .system("date +'%Y-%m-%d %H:%M:%S'")\
       ." : Completed HDZ plot for "\
       .system("date -d yesterday +'%Y-%m-%d'")

# EOF