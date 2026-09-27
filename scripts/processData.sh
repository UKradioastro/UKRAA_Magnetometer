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

PLOT_FAILURES=0

run_daily_plot() {
    local label=$1
    local plot_script=$2

    if MAGNETOMETER_BASE_PATH="$BASE_PATH" su "$FILE_OWNER" -c "/usr/bin/gnuplot $BASE_PATH/scripts/$plot_script >> $MAIN_LOG 2>> $ERROR_LOG"; then
        log_msg "processData.sh            : Completed plotting $label data" >> "$MAIN_LOG"
    else
        log_msg "processData.sh            : FAILED - look in log-error.txt for details" >> "$MAIN_LOG"
        log_msg "processData.sh            : FAILED to plot $label data" >> "$ERROR_LOG"
        PLOT_FAILURES=$((PLOT_FAILURES + 1))
    fi
}

run_daily_plot XYZ PlotDataXYZ.gp
run_daily_plot Activity PlotDataActivity.gp

# read HDZ and BI plot flags from plot.ini (defaults: true true)
PLOT_OPTIONS_OK=true
if ! PLOT_OPTIONS=$(su "$FILE_OWNER" -c "/usr/bin/python3 $BASE_PATH/scripts/GetPlotOptions.py" 2>&1); then
    log_msg "processData.sh            : FAILED - look in log-error.txt for details" >> "$MAIN_LOG"
    log_msg "processData.sh            : FAILED to read plot options: $PLOT_OPTIONS" >> "$ERROR_LOG"
    PLOT_OPTIONS_OK=false
else
    read -r PLOT_HDZ PLOT_BI PLOT_NOAA NOAA_HEMISPHERE <<< "$PLOT_OPTIONS"

    if [ -z "${PLOT_HDZ:-}" ] || [ -z "${PLOT_BI:-}" ] || [ -z "${PLOT_NOAA:-}" ] || [ -z "${NOAA_HEMISPHERE:-}" ]; then
        log_msg "processData.sh            : FAILED - look in log-error.txt for details" >> "$MAIN_LOG"
        log_msg "processData.sh            : FAILED - unexpected plot options output: '$PLOT_OPTIONS'" >> "$ERROR_LOG"
        PLOT_OPTIONS_OK=false
    fi
fi

if [ "$PLOT_OPTIONS_OK" = "true" ]; then
    # entry to plot yesterdays H, D, Z magnetic data (optional)
    if [ "$PLOT_HDZ" = "true" ]; then
        run_daily_plot HDZ PlotDataHDZ.gp
    else
        log_msg "processData.sh            : Skipping HDZ plot (plot_hdz = false in plot.ini)" >> "$MAIN_LOG"
    fi

    # entry to plot yesterdays B, I magnetic data (optional)
    if [ "$PLOT_BI" = "true" ]; then
        run_daily_plot BI PlotDataBI.gp
    else
        log_msg "processData.sh            : Skipping BI plot (plot_bi = false in plot.ini)" >> "$MAIN_LOG"
    fi
else
    log_msg "processData.sh            : Skipping HDZ and BI plots (plot options unavailable)" >> "$MAIN_LOG"
    PLOT_FAILURES=$((PLOT_FAILURES + 1))
fi

if MAGNETOMETER_BASE_PATH="$BASE_PATH" /bin/bash "$BASE_PATH/scripts/processPeriodPlots.sh"; then
    log_msg "processData.sh            : Completed period plotting" >> "$MAIN_LOG"
else
    log_msg "processData.sh            : FAILED - look in log-error.txt for details" >> "$MAIN_LOG"
    log_msg "processData.sh            : FAILED period plotting" >> "$ERROR_LOG"
    PLOT_FAILURES=$((PLOT_FAILURES + 1))
fi

if [ "$PLOT_FAILURES" -gt 0 ]; then
    log_msg "processData.sh            : Completed yesterdays processing with $PLOT_FAILURES plot failure(s)" >> "$MAIN_LOG"
    exit 1
fi

log_msg "processData.sh            : Completed yesterdays processing and plotting" >> "$MAIN_LOG"
