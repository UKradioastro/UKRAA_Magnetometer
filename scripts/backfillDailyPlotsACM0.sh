#!/bin/bash

# script backfillDailyPlotsACM0.sh to generate yesterday's HDZ/BI plot on demand
# when plot_hdz/plot_bi is enabled after having been off, so the web page doesn't
# have to wait for the next 4am cron run. Underlying minute data already exists
# (ProcessDataRawACM0.py runs daily regardless of the plot flags).

BASE_PATH=${MAGNETOMETER_BASE_PATH:-/home/pi/UKRAA_Magnetometer}
LOG_DIR="$BASE_PATH/logfiles"
MAIN_LOG="$LOG_DIR/log-MagnetometerACM0.txt"
ERROR_LOG="$LOG_DIR/log-error.txt"

log_msg() {
    printf '%s : %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1"
}

log_msg "backfillDailyPlotsACM0.sh : Started backfill check for newly enabled daily plots" >> "$MAIN_LOG"

if ! PLOT_OPTIONS=$(MAGNETOMETER_BASE_PATH="$BASE_PATH" /usr/bin/python3 "$BASE_PATH/scripts/GetPlotOptionsACM0.py" 2>&1); then
    log_msg "backfillDailyPlotsACM0.sh : FAILED to read plot options: $PLOT_OPTIONS" >> "$ERROR_LOG"
    exit 1
fi

read -r PLOT_HDZ PLOT_BI PLOT_NOAA NOAA_HEMISPHERE <<< "$PLOT_OPTIONS"

if [ -z "${PLOT_HDZ:-}" ] || [ -z "${PLOT_BI:-}" ] || [ -z "${PLOT_NOAA:-}" ] || [ -z "${NOAA_HEMISPHERE:-}" ]; then
    log_msg "backfillDailyPlotsACM0.sh : FAILED - unexpected plot options output: '$PLOT_OPTIONS'" >> "$ERROR_LOG"
    exit 1
fi

if [ "$PLOT_HDZ" = "true" ] && [ ! -f "$BASE_PATH/temp/HDZ.png" ]; then
    log_msg "backfillDailyPlotsACM0.sh : HDZ.png missing while plot_hdz=true, regenerating for yesterday" >> "$MAIN_LOG"
    if MAGNETOMETER_BASE_PATH="$BASE_PATH" su pi -c "/usr/bin/gnuplot $BASE_PATH/scripts/PlotDataHDZACM0.gp >> $MAIN_LOG 2>> $ERROR_LOG"; then
        log_msg "backfillDailyPlotsACM0.sh : Completed backfill HDZ plot" >> "$MAIN_LOG"
    else
        log_msg "backfillDailyPlotsACM0.sh : FAILED backfill HDZ plot" >> "$ERROR_LOG"
        exit 1
    fi
else
    log_msg "backfillDailyPlotsACM0.sh : No HDZ backfill needed" >> "$MAIN_LOG"
fi

if [ "$PLOT_BI" = "true" ] && [ ! -f "$BASE_PATH/temp/BI.png" ]; then
    log_msg "backfillDailyPlotsACM0.sh : BI.png missing while plot_bi=true, regenerating for yesterday" >> "$MAIN_LOG"
    if MAGNETOMETER_BASE_PATH="$BASE_PATH" su pi -c "/usr/bin/gnuplot $BASE_PATH/scripts/PlotDataBIACM0.gp >> $MAIN_LOG 2>> $ERROR_LOG"; then
        log_msg "backfillDailyPlotsACM0.sh : Completed backfill BI plot" >> "$MAIN_LOG"
    else
        log_msg "backfillDailyPlotsACM0.sh : FAILED backfill BI plot" >> "$ERROR_LOG"
        exit 1
    fi
else
    log_msg "backfillDailyPlotsACM0.sh : No BI backfill needed" >> "$MAIN_LOG"
fi

if MAGNETOMETER_BASE_PATH="$BASE_PATH" /bin/bash "$BASE_PATH/scripts/moveGraphs.sh"; then
    log_msg "backfillDailyPlotsACM0.sh : Completed publish after backfill" >> "$MAIN_LOG"
else
    log_msg "backfillDailyPlotsACM0.sh : FAILED publish after backfill" >> "$ERROR_LOG"
    exit 1
fi

log_msg "backfillDailyPlotsACM0.sh : Completed backfill check" >> "$MAIN_LOG"
