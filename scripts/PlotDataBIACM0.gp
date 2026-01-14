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

# Clear gnuplot terminal
#clear

# Set terminal 
set terminal pngcairo enhanced font "DejaVuSansCondensed, 10" rounded size 640,540 

# Set print to <stdout>
set print "-"

# print to log file
print "PlotDataBIACM0.gp          : "\
    .system("date +'%Y-%m-%d %H:%M:%S'")\
    ." : Started BI plots for "\
    .system("date -d yesterday +'%Y-%m-%d'")

# Set up data paths
pathData        = "/home/pi/UKRAA_Magnetometer/data/processed"

# Year folder
YearFolder = "/".system("date -d yesterday +'%Y'")

# YearMonth folder
YearMonthFolder = "/".system("date -d yesterday +'%Y-%m'")

# YearMonthDay file
YmdFile = "/".system("date -d yesterday +'%Y-%m-%d'").".csv"

# Path to each data file for graphing
FileData        = pathData.YearFolder.YearMonthFolder.YmdFile

# date to be processed
date = system("date -d yesterday +'%Y-%m-%d'")

# Start of X axis time
StartXaxis = system("date -d '-1 day' +'%Y-%m-%d'")." 00:00:00"

# End of X axis time
EndXaxis = system("date +'%Y-%m-%d'")." 00:00:00"

# setting output path to include data stamp
# Path to directory to store file
# top detector
pathPlot1 = "/home/pi/UKRAA_Magnetometer/plots/BI/".date."_B_plot.png"
# bottom detector
pathPlot2 = "/home/pi/UKRAA_Magnetometer/plots/BI/".date."_I_plot.png"

# set output path to Plot folder
#set output pathPlot

# Set separator to ","
set datafile separator ","

# Title for graph
# top detector
GraphTitle1 = "B magnetic field per minute data for ".system("date -d yesterday +'%A %d %B %Y'")."\n Graph is updated every day at 9.30am \n"
# bottom detector
GraphTitle2 = "I magnetic field angle per minute data for ".system("date -d yesterday +'%A %d %B %Y'")."\n Graph is updated every day at 9.30am \n"

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
set grid layerdefault linetype 0 linecolor 0 linewidth 0.500 dashtype solid,  linetype 0 linecolor 0 linewidth 0.500 dashtype solid

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

# Y-axis labels and ranges
set ylabel "Arbitary units" 
set ylabel textcolor rgb "dark-violet" rotate
set yrange [ * : * ] noreverse nowriteback


# Plot command # B(nT)
GraphTitle = GraphTitle1
set key title GraphTitle
set output pathPlot1
plot FileData using 1:14 linetype 1 linewidth 1 linecolor rgb "#0000FF" title "B magnetic field variation" with lines

# Replot to terminal and create .png image with data tag for future upload to web page
set terminal pngcairo enhanced font "DejaVuSansCondensed, 10" rounded size 640,540 

# setting output path to include data stamp

# Path to directory to store file
pathPlot = "/home/pi/UKRAA_Magnetometer/temp/B"

# set output path to Plot folder
set output pathPlot.".png"

# replot graph to Plot folder with added date tag
replot
# end replot

# Plot command # I(angle?)
GraphTitle = GraphTitle2
set key title GraphTitle
set output pathPlot2
plot FileData using 1:12 linetype 1 linewidth 1 linecolor rgb "#FF0000" title "I magnetic field angle variation" with lines

# Replot to terminal and create .png image with data tag for future upload to web page
set terminal pngcairo enhanced font "DejaVuSansCondensed, 10" rounded size 640,540 

# setting output path to include data stamp

# Path to directory to store file
pathPlot = "/home/pi/UKRAA_Magnetometer/temp/I"
# set output path to Plot folder
set output pathPlot.".png"

# replot graph to Plot folder with added date tag
replot
# end replot

# print to log file
print "PlotDataBIACM0.gp          : "\
    .system("date +'%Y-%m-%d %H:%M:%S'")\
    ." : Completed BI plots for "\
    .system("date -d yesterday +'%Y-%m-%d'")

# This is important because it closes our output file.
set output

# EOF