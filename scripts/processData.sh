#!/bin/bash

# data bash script - scrape, process and plot

source "$(dirname "${BASH_SOURCE[0]}")/magnetometer-env.sh"
LOG_DIR="$BASE_PATH/logfiles"
MAIN_LOG="$LOG_DIR/log-Magnetometer.txt"
ERROR_LOG="$LOG_DIR/log-error.txt"

# logfile message function
source "$(dirname "${BASH_SOURCE[0]}")/logging.sh"

log_msg() {
    write_log_entry "$1"
}

# log message to main logfile
log_msg "processData.sh            : Started yesterdays processing and plotting" >> "$MAIN_LOG"

# entry to process yesterdays data
if MAGNETOMETER_BASE_PATH="$BASE_PATH" su "$FILE_OWNER" -c "/usr/bin/python3 $BASE_PATH/scripts/ProcessDataRaw.py >> $MAIN_LOG 2>> $ERROR_LOG"; then
    log_msg "processData.sh            : Completed processing yesterdays data" >> "$MAIN_LOG"
else
    log_msg "processData.sh            : FAILED - look in log-error.txt for details" >> "$MAIN_LOG"
    log_msg "processData.sh            : FAILED to process yesterdays data" >> "$ERROR_LOG"
    exit 1
fi

# Build the one-record-per-day source used by week-to-year plots.
if MAGNETOMETER_BASE_PATH="$BASE_PATH" su "$FILE_OWNER" -c "/usr/bin/python3 $BASE_PATH/scripts/ProcessDailySummary.py >> $MAIN_LOG 2>> $ERROR_LOG"; then
    log_msg "processData.sh            : Completed daily summary processing" >> "$MAIN_LOG"
else
    log_msg "processData.sh            : FAILED - look in log-error.txt for details" >> "$MAIN_LOG"
    log_msg "processData.sh            : FAILED to process daily summary" >> "$ERROR_LOG"
    exit 1
fi

# entry to process yesterdays hourly data
if MAGNETOMETER_BASE_PATH="$BASE_PATH" su "$FILE_OWNER" -c "/usr/bin/python3 $BASE_PATH/scripts/ProcessDataHour.py >> $MAIN_LOG 2>> $ERROR_LOG"; then
    log_msg "processData.sh            : Completed processing yesterdays hourly data" >> "$MAIN_LOG"
else
    log_msg "processData.sh            : FAILED - look in log-error.txt for details" >> "$MAIN_LOG"
    log_msg "processData.sh            : FAILED to process yesterdays hourly data" >> "$ERROR_LOG"
    exit 1
fi

# entry to plot yesterdays XYZ magnetic data
if MAGNETOMETER_BASE_PATH="$BASE_PATH" MAGNETOMETER_PLOT_PERIOD=day su "$FILE_OWNER" -c "/usr/bin/gnuplot $BASE_PATH/scripts/PlotPeriodXYZ.gp >> $MAIN_LOG 2>> $ERROR_LOG"; then
    log_msg "processData.sh            : Completed plotting XYZ data" >> "$MAIN_LOG"
else
    log_msg "processData.sh            : FAILED - look in log-error.txt for details" >> "$MAIN_LOG"
    log_msg "processData.sh            : FAILED to plot XYZ data" >> "$ERROR_LOG"
    exit 1
fi

# entry to plot yesterdays Activity magnetic data
if MAGNETOMETER_BASE_PATH="$BASE_PATH" su "$FILE_OWNER" -c "/usr/bin/gnuplot $BASE_PATH/scripts/PlotDataActivity.gp >> $MAIN_LOG 2>> $ERROR_LOG"; then
    log_msg "processData.sh            : Completed plotting Activity data" >> "$MAIN_LOG"
else
    log_msg "processData.sh            : FAILED - look in log-error.txt for details" >> "$MAIN_LOG"
    log_msg "processData.sh            : FAILED to plot Activity data" >> "$ERROR_LOG"
    exit 1
fi

# read HDZ and BI plot flags from plot.ini (defaults: true true)
if ! PLOT_OPTIONS=$(su "$FILE_OWNER" -c "/usr/bin/python3 $BASE_PATH/scripts/GetPlotOptions.py" 2>&1); then
    log_msg "processData.sh            : FAILED - look in log-error.txt for details" >> "$MAIN_LOG"
    log_msg "processData.sh            : FAILED to read plot options: $PLOT_OPTIONS" >> "$ERROR_LOG"
    exit 1
fi

read -r PLOT_HDZ PLOT_BI PLOT_NOAA NOAA_HEMISPHERE <<< "$PLOT_OPTIONS"

if [ -z "${PLOT_HDZ:-}" ] || [ -z "${PLOT_BI:-}" ] || [ -z "${PLOT_NOAA:-}" ] || [ -z "${NOAA_HEMISPHERE:-}" ]; then
    log_msg "processData.sh            : FAILED - look in log-error.txt for details" >> "$MAIN_LOG"
    log_msg "processData.sh            : FAILED - unexpected plot options output: '$PLOT_OPTIONS'" >> "$ERROR_LOG"
    exit 1
fi

# entry to plot yesterdays H, D, Z magnetic data (optional)
if [ "$PLOT_HDZ" = "true" ]; then
    if MAGNETOMETER_BASE_PATH="$BASE_PATH" MAGNETOMETER_PLOT_PERIOD=day su "$FILE_OWNER" -c "/usr/bin/gnuplot $BASE_PATH/scripts/PlotPeriodHDZ.gp >> $MAIN_LOG 2>> $ERROR_LOG"; then
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
    if MAGNETOMETER_BASE_PATH="$BASE_PATH" MAGNETOMETER_PLOT_PERIOD=day su "$FILE_OWNER" -c "/usr/bin/gnuplot $BASE_PATH/scripts/PlotPeriodBI.gp >> $MAIN_LOG 2>> $ERROR_LOG"; then
        log_msg "processData.sh            : Completed plotting BI data" >> "$MAIN_LOG"
    else
        log_msg "processData.sh            : FAILED - look in log-error.txt for details" >> "$MAIN_LOG"
        log_msg "processData.sh            : FAILED to plot BI data" >> "$ERROR_LOG"
        exit 1
    fi
else
    log_msg "processData.sh            : Skipping BI plot (plot_bi = false in plot.ini)" >> "$MAIN_LOG"
fi

if MAGNETOMETER_BASE_PATH="$BASE_PATH" /bin/bash "$BASE_PATH/scripts/processPeriodPlots.sh"; then
    log_msg "processData.sh            : Completed period plotting" >> "$MAIN_LOG"
else
    log_msg "processData.sh            : FAILED - look in log-error.txt for details" >> "$MAIN_LOG"
    log_msg "processData.sh            : FAILED period plotting" >> "$ERROR_LOG"
    exit 1
fi

log_msg "processData.sh            : Completed yesterdays processing and plotting" >> "$MAIN_LOG"
