#!/bin/bash

set -u

BASE_PATH=${MAGNETOMETER_BASE_PATH:-/home/pi/UKRAA_Magnetometer}
LOG_DIR="$BASE_PATH/logfiles"
MAIN_LOG="$LOG_DIR/log-MagnetometerACM0.txt"
ERROR_LOG="$LOG_DIR/log-error.txt"
WINDOWS="7d 1m 3m 6m 1y"

log_msg() {
    printf '%s : %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1"
}

log_msg "processHistoricalData.sh : Started generating historical plots" >> "$MAIN_LOG"

if [ ! -d "$BASE_PATH/scripts" ]; then
    log_msg "processHistoricalData.sh : FAILED - scripts directory missing" >> "$ERROR_LOG"
    exit 1
fi

for window in $WINDOWS; do
    if MAGNETOMETER_BASE_PATH="$BASE_PATH" /usr/bin/python3 "$BASE_PATH/scripts/ProcessHistoryACM0.py" --window "$window" >> "$MAIN_LOG" 2>> "$ERROR_LOG"; then
        log_msg "processHistoricalData.sh : Completed history CSV for $window" >> "$MAIN_LOG"
    else
        log_msg "processHistoricalData.sh : FAILED history CSV for $window" >> "$ERROR_LOG"
        exit 1
    fi

    if MAGNETOMETER_BASE_PATH="$BASE_PATH" MAGNETOMETER_HISTORY_WINDOW="$window" /usr/bin/gnuplot "$BASE_PATH/scripts/PlotHistoryXYZACM0.gp" >> "$MAIN_LOG" 2>> "$ERROR_LOG"; then
        log_msg "processHistoricalData.sh : Completed XYZ history plot for $window" >> "$MAIN_LOG"
    else
        log_msg "processHistoricalData.sh : FAILED XYZ history plot for $window" >> "$ERROR_LOG"
        exit 1
    fi

    read -r PLOT_HDZ PLOT_BI < <(MAGNETOMETER_BASE_PATH="$BASE_PATH" /usr/bin/python3 "$BASE_PATH/scripts/GetPlotOptionsACM0.py")

    if [ "$PLOT_HDZ" = "true" ]; then
        if MAGNETOMETER_BASE_PATH="$BASE_PATH" MAGNETOMETER_HISTORY_WINDOW="$window" /usr/bin/gnuplot "$BASE_PATH/scripts/PlotHistoryHDZACM0.gp" >> "$MAIN_LOG" 2>> "$ERROR_LOG"; then
            log_msg "processHistoricalData.sh : Completed HDZ history plot for $window" >> "$MAIN_LOG"
        else
            log_msg "processHistoricalData.sh : FAILED HDZ history plot for $window" >> "$ERROR_LOG"
            exit 1
        fi
    else
        log_msg "processHistoricalData.sh : Skipping HDZ history plot for $window" >> "$MAIN_LOG"
    fi

    if [ "$PLOT_BI" = "true" ]; then
        if MAGNETOMETER_BASE_PATH="$BASE_PATH" MAGNETOMETER_HISTORY_WINDOW="$window" /usr/bin/gnuplot "$BASE_PATH/scripts/PlotHistoryBIACM0.gp" >> "$MAIN_LOG" 2>> "$ERROR_LOG"; then
            log_msg "processHistoricalData.sh : Completed BI history plot for $window" >> "$MAIN_LOG"
        else
            log_msg "processHistoricalData.sh : FAILED BI history plot for $window" >> "$ERROR_LOG"
            exit 1
        fi
    else
        log_msg "processHistoricalData.sh : Skipping BI history plot for $window" >> "$MAIN_LOG"
    fi
done

log_msg "processHistoricalData.sh : Completed generating historical plots" >> "$MAIN_LOG"
