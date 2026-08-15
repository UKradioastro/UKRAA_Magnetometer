#!/bin/bash

# script processHistoricalData.sh to build and plot the 7d/1m/3m/6m/1y
# historical windows, run once per day after the daily hourly data is ready.

BASE_PATH=${MAGNETOMETER_BASE_PATH:-/home/pi/UKRAA_Magnetometer}
LOG_DIR="$BASE_PATH/logfiles"
MAIN_LOG="$LOG_DIR/log-MagnetometerACM0.txt"
ERROR_LOG="$LOG_DIR/log-error.txt"
HISTORY_WINDOWS="7d 1m 3m 6m 1y"

log_msg() {
    printf '%s : %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1"
}

log_msg "processHistoricalData.sh : Started building historical plots" >> "$MAIN_LOG"

# read HDZ and BI plot flags from plot.ini (defaults: true true)
read -r PLOT_HDZ PLOT_BI < <(MAGNETOMETER_BASE_PATH="$BASE_PATH" su pi -c "/usr/bin/python3 $BASE_PATH/scripts/GetPlotOptionsACM0.py")

for window in $HISTORY_WINDOWS; do
    if MAGNETOMETER_BASE_PATH="$BASE_PATH" su pi -c "/usr/bin/python3 $BASE_PATH/scripts/ProcessHistoryACM0.py --window $window >> $MAIN_LOG 2>> $ERROR_LOG"; then
        log_msg "processHistoricalData.sh : Completed history data for window $window" >> "$MAIN_LOG"
    else
        log_msg "processHistoricalData.sh : FAILED history data for window $window" >> "$ERROR_LOG"
        exit 1
    fi

    if MAGNETOMETER_BASE_PATH="$BASE_PATH" MAGNETOMETER_HISTORY_WINDOW="$window" su pi -c "/usr/bin/gnuplot $BASE_PATH/scripts/PlotHistoryXYZACM0.gp >> $MAIN_LOG 2>> $ERROR_LOG"; then
        log_msg "processHistoricalData.sh : Completed XYZ history plot for window $window" >> "$MAIN_LOG"
    else
        log_msg "processHistoricalData.sh : FAILED XYZ history plot for window $window" >> "$ERROR_LOG"
        exit 1
    fi

    if [ "$PLOT_HDZ" = "true" ]; then
        if MAGNETOMETER_BASE_PATH="$BASE_PATH" MAGNETOMETER_HISTORY_WINDOW="$window" su pi -c "/usr/bin/gnuplot $BASE_PATH/scripts/PlotHistoryHDZACM0.gp >> $MAIN_LOG 2>> $ERROR_LOG"; then
            log_msg "processHistoricalData.sh : Completed HDZ history plot for window $window" >> "$MAIN_LOG"
        else
            log_msg "processHistoricalData.sh : FAILED HDZ history plot for window $window" >> "$ERROR_LOG"
            exit 1
        fi
    else
        log_msg "processHistoricalData.sh : Skipping HDZ history plot for window $window (plot_hdz = false in plot.ini)" >> "$MAIN_LOG"
    fi

    if [ "$PLOT_BI" = "true" ]; then
        if MAGNETOMETER_BASE_PATH="$BASE_PATH" MAGNETOMETER_HISTORY_WINDOW="$window" su pi -c "/usr/bin/gnuplot $BASE_PATH/scripts/PlotHistoryBIACM0.gp >> $MAIN_LOG 2>> $ERROR_LOG"; then
            log_msg "processHistoricalData.sh : Completed BI history plot for window $window" >> "$MAIN_LOG"
        else
            log_msg "processHistoricalData.sh : FAILED BI history plot for window $window" >> "$ERROR_LOG"
            exit 1
        fi
    else
        log_msg "processHistoricalData.sh : Skipping BI history plot for window $window (plot_bi = false in plot.ini)" >> "$MAIN_LOG"
    fi
done

log_msg "processHistoricalData.sh : Completed building historical plots" >> "$MAIN_LOG"
