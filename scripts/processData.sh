#!/bin/bash

# data bash script - scrape, process and plot

BASE_PATH=${MAGNETOMETER_BASE_PATH:-/home/pi/UKRAA_Magnetometer}
LOG_DIR="$BASE_PATH/logfiles"
MAIN_LOG="$LOG_DIR/log-MagnetometerACM0.txt"
ERROR_LOG="$LOG_DIR/log-error.txt"

# logfile message function
log_msg() {
    printf '%s : %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1"
}

# log message to main logfile
log_msg "processData.sh            : Started yesterdays processing and plotting" >> "$MAIN_LOG"

# entry to process yesterdays data
if MAGNETOMETER_BASE_PATH="$BASE_PATH" su pi -c "/usr/bin/python3 $BASE_PATH/scripts/ProcessDataRawACM0.py >> $MAIN_LOG 2>> $ERROR_LOG"; then
    log_msg "processData.sh            : Completed processing yesterdays data" >> "$MAIN_LOG"
else
    log_msg "processData.sh            : FAILED - look in log-error.txt for details" >> "$MAIN_LOG"
    log_msg "processData.sh            : FAILED to process yesterdays data" >> "$ERROR_LOG"
    exit 1
fi

# entry to process yesterdays hourly data
if MAGNETOMETER_BASE_PATH="$BASE_PATH" su pi -c "/usr/bin/python3 $BASE_PATH/scripts/ProcessDataHourACM0.py >> $MAIN_LOG 2>> $ERROR_LOG"; then
    log_msg "processData.sh            : Completed processing yesterdays hourly data" >> "$MAIN_LOG"
else
    log_msg "processData.sh            : FAILED - look in log-error.txt for details" >> "$MAIN_LOG"
    log_msg "processData.sh            : FAILED to process yesterdays hourly data" >> "$ERROR_LOG"
    exit 1
fi

# entry to plot yesterdays XYZ magnetic data
if MAGNETOMETER_BASE_PATH="$BASE_PATH" su pi -c "/usr/bin/gnuplot $BASE_PATH/scripts/PlotDataXYZACM0.gp >> $MAIN_LOG 2>> $ERROR_LOG"; then
    log_msg "processData.sh            : Completed plotting XYZ data" >> "$MAIN_LOG"
else
    log_msg "processData.sh            : FAILED - look in log-error.txt for details" >> "$MAIN_LOG"
    log_msg "processData.sh            : FAILED to plot XYZ data" >> "$ERROR_LOG"
    exit 1
fi

# entry to plot yesterdays Activity magnetic data
if MAGNETOMETER_BASE_PATH="$BASE_PATH" su pi -c "/usr/bin/gnuplot $BASE_PATH/scripts/PlotDataActivityACM0.gp >> $MAIN_LOG 2>> $ERROR_LOG"; then
    log_msg "processData.sh            : Completed plotting Activity data" >> "$MAIN_LOG"
else
    log_msg "processData.sh            : FAILED - look in log-error.txt for details" >> "$MAIN_LOG"
    log_msg "processData.sh            : FAILED to plot Activity data" >> "$ERROR_LOG"
    exit 1
fi

# read HDZ and BI plot flags from plot.ini (defaults: true true)
if ! PLOT_OPTIONS=$(su pi -c "/usr/bin/python3 /home/pi/UKRAA_Magnetometer/scripts/GetPlotOptionsACM0.py" 2>&1); then
    log_msg "processData.sh            : FAILED - look in log-error.txt for details" >> "$MAIN_LOG"
    log_msg "processData.sh            : FAILED to read plot options: $PLOT_OPTIONS" >> "$ERROR_LOG"
    exit 1
fi

read -r PLOT_HDZ PLOT_BI <<< "$PLOT_OPTIONS"

if [ -z "${PLOT_HDZ:-}" ] || [ -z "${PLOT_BI:-}" ]; then
    log_msg "processData.sh            : FAILED - look in log-error.txt for details" >> "$MAIN_LOG"
    log_msg "processData.sh            : FAILED - unexpected plot options output: '$PLOT_OPTIONS'" >> "$ERROR_LOG"
    exit 1
fi

# entry to plot yesterdays H, D, Z magnetic data (optional)
if [ "$PLOT_HDZ" = "true" ]; then
    if MAGNETOMETER_BASE_PATH="$BASE_PATH" su pi -c "/usr/bin/gnuplot $BASE_PATH/scripts/PlotDataHDZACM0.gp >> $MAIN_LOG 2>> $ERROR_LOG"; then
        log_msg "processData.sh            : Completed plotting HDZ data" >> "$MAIN_LOG"
    else
        log_msg "processData.sh            : FAILED - look in log-error.txt for details" >> "$MAIN_LOG"
        log_msg "processData.sh            : FAILED to plot HDZ data" >> "$ERROR_LOG"
        exit 1
    fi
else
    log_msg "processData.sh            : Skipping HDZ plot (plot_hdz = false in plot.ini)" >> "$MAIN_LOG"
fi

# entry to plot yesterdays B, I magnetic data (optional)
if [ "$PLOT_BI" = "true" ]; then
    if MAGNETOMETER_BASE_PATH="$BASE_PATH" su pi -c "/usr/bin/gnuplot $BASE_PATH/scripts/PlotDataBIACM0.gp >> $MAIN_LOG 2>> $ERROR_LOG"; then
        log_msg "processData.sh            : Completed plotting BI data" >> "$MAIN_LOG"
    else
        log_msg "processData.sh            : FAILED - look in log-error.txt for details" >> "$MAIN_LOG"
        log_msg "processData.sh            : FAILED to plot BI data" >> "$ERROR_LOG"
        exit 1
    fi
else
    log_msg "processData.sh            : Skipping BI plot (plot_bi = false in plot.ini)" >> "$MAIN_LOG"
fi

log_msg "processData.sh            : Completed yesterdays processing and plotting" >> "$MAIN_LOG"
