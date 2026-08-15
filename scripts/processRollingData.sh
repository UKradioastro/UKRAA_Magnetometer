#!/bin/bash

BASE_PATH=${MAGNETOMETER_BASE_PATH:-/home/pi/UKRAA_Magnetometer}
LOG_DIR="$BASE_PATH/logfiles"
MAIN_LOG="$LOG_DIR/log-MagnetometerACM0.txt"
ERROR_LOG="$LOG_DIR/log-error.txt"

log_msg() {
    printf '%s : %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1"
}

log_msg "processRollingData.sh    : Started rolling processing and publishing" >> "$MAIN_LOG"

if MAGNETOMETER_BASE_PATH="$BASE_PATH" su pi -c "/usr/bin/python3 $BASE_PATH/scripts/ProcessRollingACM0.py >> $MAIN_LOG 2>> $ERROR_LOG"; then
    log_msg "processRollingData.sh    : Completed rolling data processing" >> "$MAIN_LOG"
else
    log_msg "processRollingData.sh    : FAILED rolling data processing" >> "$ERROR_LOG"
    exit 1
fi

if MAGNETOMETER_BASE_PATH="$BASE_PATH" su pi -c "/usr/bin/gnuplot $BASE_PATH/scripts/PlotRollingXYZACM0.gp >> $MAIN_LOG 2>> $ERROR_LOG"; then
    log_msg "processRollingData.sh    : Completed rolling XYZ plot" >> "$MAIN_LOG"
else
    log_msg "processRollingData.sh    : FAILED rolling XYZ plot" >> "$ERROR_LOG"
    exit 1
fi

if MAGNETOMETER_BASE_PATH="$BASE_PATH" su pi -c "/usr/bin/gnuplot $BASE_PATH/scripts/PlotRollingActivityACM0.gp >> $MAIN_LOG 2>> $ERROR_LOG"; then
    log_msg "processRollingData.sh    : Completed rolling activity plot" >> "$MAIN_LOG"
else
    log_msg "processRollingData.sh    : FAILED rolling activity plot" >> "$ERROR_LOG"
    exit 1
fi

# read HDZ and BI plot flags from plot.ini (defaults: true true)
read -r PLOT_HDZ PLOT_BI < <(su pi -c "/usr/bin/python3 $BASE_PATH/scripts/GetPlotOptionsACM0.py")

if [ "$PLOT_HDZ" = "true" ]; then
    if MAGNETOMETER_BASE_PATH="$BASE_PATH" su pi -c "/usr/bin/gnuplot $BASE_PATH/scripts/PlotRollingHDZACM0.gp >> $MAIN_LOG 2>> $ERROR_LOG"; then
        log_msg "processRollingData.sh    : Completed rolling HDZ plot" >> "$MAIN_LOG"
    else
        log_msg "processRollingData.sh    : FAILED rolling HDZ plot" >> "$ERROR_LOG"
        exit 1
    fi
else
    log_msg "processRollingData.sh    : Skipping rolling HDZ plot (plot_hdz = false in plot.ini)" >> "$MAIN_LOG"
fi

if [ "$PLOT_BI" = "true" ]; then
    if MAGNETOMETER_BASE_PATH="$BASE_PATH" su pi -c "/usr/bin/gnuplot $BASE_PATH/scripts/PlotRollingBIACM0.gp >> $MAIN_LOG 2>> $ERROR_LOG"; then
        log_msg "processRollingData.sh    : Completed rolling BI plot" >> "$MAIN_LOG"
    else
        log_msg "processRollingData.sh    : FAILED rolling BI plot" >> "$ERROR_LOG"
        exit 1
    fi
else
    log_msg "processRollingData.sh    : Skipping rolling BI plot (plot_bi = false in plot.ini)" >> "$MAIN_LOG"
fi

if MAGNETOMETER_BASE_PATH="$BASE_PATH" su pi -c "/usr/bin/python3 $BASE_PATH/scripts/EvaluateAlertsACM0.py >> $MAIN_LOG 2>> $ERROR_LOG"; then
    log_msg "processRollingData.sh    : Completed rolling alert evaluation" >> "$MAIN_LOG"
else
    log_msg "processRollingData.sh    : FAILED rolling alert evaluation" >> "$ERROR_LOG"
    exit 1
fi

if MAGNETOMETER_BASE_PATH="$BASE_PATH" /bin/bash "$BASE_PATH/scripts/publishWebACM0.sh"; then
    log_msg "processRollingData.sh    : Completed rolling publish" >> "$MAIN_LOG"

    if MAGNETOMETER_BASE_PATH="$BASE_PATH" /bin/bash "$BASE_PATH/scripts/uploadRemoteACM0.sh" rolling; then
        log_msg "processRollingData.sh    : Completed remote rolling upload" >> "$MAIN_LOG"
    else
        log_msg "processRollingData.sh    : FAILED remote rolling upload (local publish kept)" >> "$ERROR_LOG"
    fi
else
    log_msg "processRollingData.sh    : FAILED rolling publish" >> "$ERROR_LOG"
    exit 1
fi

log_msg "processRollingData.sh    : Completed rolling processing and publishing" >> "$MAIN_LOG"