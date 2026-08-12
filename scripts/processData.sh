#!/bin/bash

# data bash script - scrape, process and plot

LOG_DIR=/home/pi/UKRAA_Magnetometer/logfiles
MAIN_LOG="$LOG_DIR/log-MagnetometerACM0.txt"
ERROR_LOG="$LOG_DIR/log-error.txt"

# logfile message function
log_msg() {
    printf '%s : %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1"
}

# log message to main logfile
log_msg "processData.sh          : Started processing and plotting" >> "$MAIN_LOG"

# entry to process yesterdays data
if su pi -c "/usr/bin/python3 /home/pi/UKRAA_Magnetometer/scripts/ProcessDataRawACM0.py \
                        >> /home/pi/UKRAA_Magnetometer/logfiles/log-MagnetometerACM0.txt \
                       2>> /home/pi/UKRAA_Magnetometer/logfiles/log-error.txt"; then
    log_msg "processData.sh          : Completed processing yesterdays data" >> "$MAIN_LOG"
else
    log_msg "processData.sh          : FAILED - look in log-error.txt for details" >> "$MAIN_LOG"
    log_msg "processData.sh          : FAILED to process yesterdays data" >> "$ERROR_LOG"
    exit 1
fi

# entry to process yesterdays hourly data
if su pi -c "/usr/bin/python3 /home/pi/UKRAA_Magnetometer/scripts/ProcessDataHourACM0.py \
                        >> /home/pi/UKRAA_Magnetometer/logfiles/log-MagnetometerACM0.txt \
                       2>> /home/pi/UKRAA_Magnetometer/logfiles/log-error.txt"; then
    log_msg "processData.sh          : Completed processing yesterdays hourly data" >> "$MAIN_LOG"
else
    log_msg "processData.sh          : FAILED - look in log-error.txt for details" >> "$MAIN_LOG"
    log_msg "processData.sh          : FAILED to process yesterdays hourly data" >> "$ERROR_LOG"
    exit 1
fi

# entry to plot yesterdays XYZ magnetic data
if su pi -c "/usr/bin/gnuplot /home/pi/UKRAA_Magnetometer/scripts/PlotDataXYZACM0.gp\
                        >> /home/pi/UKRAA_Magnetometer/logfiles/log-MagnetometerACM0.txt \
                       2>> /home/pi/UKRAA_Magnetometer/logfiles/log-error.txt"; then
    log_msg "processData.sh          : Completed plotting XYZ data" >> "$MAIN_LOG"
else
    log_msg "processData.sh          : FAILED - look in log-error.txt for details" >> "$MAIN_LOG"
    log_msg "processData.sh          : FAILED to plot XYZ data" >> "$ERROR_LOG"
    exit 1
fi

# entry to plot yesterdays Activity magnetic data
if su pi -c "/usr/bin/gnuplot /home/pi/UKRAA_Magnetometer/scripts/PlotDataActivityACM0.gp\
                        >> /home/pi/UKRAA_Magnetometer/logfiles/log-MagnetometerACM0.txt \
                       2>> /home/pi/UKRAA_Magnetometer/logfiles/log-error.txt"; then
    log_msg "processData.sh          : Completed plotting Activity data" >> "$MAIN_LOG"
else
    log_msg "processData.sh          : FAILED - look in log-error.txt for details" >> "$MAIN_LOG"
    log_msg "processData.sh          : FAILED to plot Activity data" >> "$ERROR_LOG"
    exit 1
fi

# read HDZ and BI plot flags from plot.ini (defaults: true true)
read -r PLOT_HDZ PLOT_BI < <(su pi -c "/usr/bin/python3 /home/pi/UKRAA_Magnetometer/scripts/GetPlotOptionsACM0.py")

# entry to plot yesterdays H, D, Z magnetic data (optional)
if [ "$PLOT_HDZ" = "true" ]; then
    if su pi -c "/usr/bin/gnuplot /home/pi/UKRAA_Magnetometer/scripts/PlotDataHDZACM0.gp\
                            >> /home/pi/UKRAA_Magnetometer/logfiles/log-MagnetometerACM0.txt \
                           2>> /home/pi/UKRAA_Magnetometer/logfiles/log-error.txt"; then
        log_msg "processData.sh          : Completed plotting HDZ data" >> "$MAIN_LOG"
    else
        log_msg "processData.sh          : FAILED - look in log-error.txt for details" >> "$MAIN_LOG"
        log_msg "processData.sh          : FAILED to plot HDZ data" >> "$ERROR_LOG"
        exit 1
    fi
else
    log_msg "processData.sh          : Skipping HDZ plot (plot_hdz = false in plot.ini)" >> "$MAIN_LOG"
fi

# entry to plot yesterdays B, I magnetic data (optional)
if [ "$PLOT_BI" = "true" ]; then
    if su pi -c "/usr/bin/gnuplot /home/pi/UKRAA_Magnetometer/scripts/PlotDataBIACM0.gp\
                            >> /home/pi/UKRAA_Magnetometer/logfiles/log-MagnetometerACM0.txt \
                           2>> /home/pi/UKRAA_Magnetometer/logfiles/log-error.txt"; then
        log_msg "processData.sh          : Completed plotting BI data" >> "$MAIN_LOG"
    else
        log_msg "processData.sh          : FAILED - look in log-error.txt for details" >> "$MAIN_LOG"
        log_msg "processData.sh          : FAILED to plot BI data" >> "$ERROR_LOG"
        exit 1
    fi
else
    log_msg "processData.sh          : Skipping BI plot (plot_bi = false in plot.ini)" >> "$MAIN_LOG"
fi

# entry to generate multi-window historical plots (7d, 1m, 3m, 6m, 1y)
if su pi -c "/bin/bash /home/pi/UKRAA_Magnetometer/scripts/processHistoricalData.sh \
                        >> /home/pi/UKRAA_Magnetometer/logfiles/log-MagnetometerACM0.txt \
                       2>> /home/pi/UKRAA_Magnetometer/logfiles/log-error.txt"; then
    log_msg "processData.sh          : Completed historical plot generation" >> "$MAIN_LOG"
else
    log_msg "processData.sh          : FAILED - look in log-error.txt for details" >> "$MAIN_LOG"
    log_msg "processData.sh          : FAILED to generate historical plots" >> "$ERROR_LOG"
    exit 1
fi

log_msg "processData.sh          : Completed processing and plotting" >> "$MAIN_LOG"
