#!/bin/bash

# script backfillDailyPlots.sh to generate yesterday's HDZ/BI plot on demand
# when plot_hdz/plot_bi is enabled after having been off, so the web page doesn't
# have to wait for the next 4am cron run. Underlying minute data already exists
# (ProcessDataRaw.py runs daily regardless of the plot flags).

source "$(dirname "${BASH_SOURCE[0]}")/magnetometer-env.sh"
LOG_DIR="$BASE_PATH/logfiles"
MAIN_LOG="$LOG_DIR/log-Magnetometer.txt"
ERROR_LOG="$LOG_DIR/log-error.txt"

source "$(dirname "${BASH_SOURCE[0]}")/logging.sh"

log_msg() {
    write_log_entry "$1"
}

log_msg "backfillDailyPlots.sh : Started backfill check for newly enabled daily plots" >> "$MAIN_LOG"

if ! PLOT_OPTIONS=$(MAGNETOMETER_BASE_PATH="$BASE_PATH" /usr/bin/python3 "$BASE_PATH/scripts/GetPlotOptions.py" 2>&1); then
    log_msg "backfillDailyPlots.sh : FAILED to read plot options: $PLOT_OPTIONS" >> "$ERROR_LOG"
    exit 1
fi

read -r PLOT_HDZ PLOT_BI PLOT_NOAA NOAA_HEMISPHERE <<< "$PLOT_OPTIONS"

if [ -z "${PLOT_HDZ:-}" ] || [ -z "${PLOT_BI:-}" ] || [ -z "${PLOT_NOAA:-}" ] || [ -z "${NOAA_HEMISPHERE:-}" ]; then
    log_msg "backfillDailyPlots.sh : FAILED - unexpected plot options output: '$PLOT_OPTIONS'" >> "$ERROR_LOG"
    exit 1
fi

if [ "$PLOT_HDZ" = "true" ] && [ ! -f "$BASE_PATH/temp/yesterday/HDZ.png" ]; then
    log_msg "backfillDailyPlots.sh : HDZ.png missing while plot_hdz=true, regenerating for yesterday" >> "$MAIN_LOG"
    if MAGNETOMETER_BASE_PATH="$BASE_PATH" su "$FILE_OWNER" -c "/usr/bin/gnuplot $BASE_PATH/scripts/PlotDataHDZ.gp >> $MAIN_LOG 2>> $ERROR_LOG"; then
        log_msg "backfillDailyPlots.sh : Completed backfill HDZ plot" >> "$MAIN_LOG"
    else
        log_msg "backfillDailyPlots.sh : FAILED backfill HDZ plot" >> "$ERROR_LOG"
        exit 1
    fi
else
    log_msg "backfillDailyPlots.sh : No HDZ backfill needed" >> "$MAIN_LOG"
fi

if [ "$PLOT_BI" = "true" ] && [ ! -f "$BASE_PATH/temp/yesterday/BI.png" ]; then
    log_msg "backfillDailyPlots.sh : BI.png missing while plot_bi=true, regenerating for yesterday" >> "$MAIN_LOG"
    if MAGNETOMETER_BASE_PATH="$BASE_PATH" su "$FILE_OWNER" -c "/usr/bin/gnuplot $BASE_PATH/scripts/PlotDataBI.gp >> $MAIN_LOG 2>> $ERROR_LOG"; then
        log_msg "backfillDailyPlots.sh : Completed backfill BI plot" >> "$MAIN_LOG"
    else
        log_msg "backfillDailyPlots.sh : FAILED backfill BI plot" >> "$ERROR_LOG"
        exit 1
    fi
else
    log_msg "backfillDailyPlots.sh : No BI backfill needed" >> "$MAIN_LOG"
fi

if MAGNETOMETER_BASE_PATH="$BASE_PATH" /bin/bash "$BASE_PATH/scripts/moveGraphs.sh"; then
    log_msg "backfillDailyPlots.sh : Completed publish after backfill" >> "$MAIN_LOG"
else
    log_msg "backfillDailyPlots.sh : FAILED publish after backfill" >> "$ERROR_LOG"
    exit 1
fi

log_msg "backfillDailyPlots.sh : Completed backfill check" >> "$MAIN_LOG"
