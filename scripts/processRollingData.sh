#!/bin/bash

source "$(dirname "${BASH_SOURCE[0]}")/magnetometer-env.sh"
LOG_DIR="$BASE_PATH/logfiles"
MAIN_LOG="$LOG_DIR/log-Magnetometer.txt"
ERROR_LOG="$LOG_DIR/log-error.txt"

source "$(dirname "${BASH_SOURCE[0]}")/logging.sh"

log_msg() {
    write_log_entry "$1"
}

log_msg "processRollingData.sh     : Started rolling processing and publishing" >> "$MAIN_LOG"

if MAGNETOMETER_BASE_PATH="$BASE_PATH" su "$FILE_OWNER" -c "/usr/bin/python3 $BASE_PATH/scripts/ProcessRolling.py >> $MAIN_LOG 2>> $ERROR_LOG"; then
    log_msg "processRollingData.sh     : Completed rolling data processing" >> "$MAIN_LOG"
else
    log_msg "processRollingData.sh     : FAILED - look in log-error.txt for details" >> "$MAIN_LOG"
    log_msg "processRollingData.sh     : FAILED rolling data processing" >> "$ERROR_LOG"
    exit 1
fi

if MAGNETOMETER_BASE_PATH="$BASE_PATH" su "$FILE_OWNER" -c "/usr/bin/gnuplot $BASE_PATH/scripts/PlotRollingXYZ.gp >> $MAIN_LOG 2>> $ERROR_LOG"; then
    log_msg "processRollingData.sh     : Completed rolling XYZ plot" >> "$MAIN_LOG"
else
    log_msg "processRollingData.sh     : FAILED - look in log-error.txt for details" >> "$MAIN_LOG"
    log_msg "processRollingData.sh     : FAILED rolling XYZ plot" >> "$ERROR_LOG"
    exit 1
fi

if MAGNETOMETER_BASE_PATH="$BASE_PATH" su "$FILE_OWNER" -c "/usr/bin/gnuplot $BASE_PATH/scripts/PlotRollingActivity.gp >> $MAIN_LOG 2>> $ERROR_LOG"; then
    log_msg "processRollingData.sh     : Completed rolling activity plot" >> "$MAIN_LOG"
else
    log_msg "processRollingData.sh     : FAILED - look in log-error.txt for details" >> "$MAIN_LOG"
    log_msg "processRollingData.sh     : FAILED rolling activity plot" >> "$ERROR_LOG"
    exit 1
fi

# read HDZ and BI plot flags from plot.ini (defaults: true true)
if ! PLOT_OPTIONS=$(su "$FILE_OWNER" -c "/usr/bin/python3 $BASE_PATH/scripts/GetPlotOptions.py" 2>&1); then
    log_msg "processRollingData.sh     : FAILED - look in log-error.txt for details" >> "$MAIN_LOG"
    log_msg "processRollingData.sh     : FAILED to read plot options: $PLOT_OPTIONS" >> "$ERROR_LOG"
    exit 1
fi

read -r PLOT_HDZ PLOT_BI PLOT_NOAA NOAA_HEMISPHERE <<< "$PLOT_OPTIONS"

if [ -z "${PLOT_HDZ:-}" ] || [ -z "${PLOT_BI:-}" ] || [ -z "${PLOT_NOAA:-}" ] || [ -z "${NOAA_HEMISPHERE:-}" ]; then
    log_msg "processRollingData.sh     : FAILED - look in log-error.txt for details" >> "$MAIN_LOG"
    log_msg "processRollingData.sh     : FAILED - unexpected plot options output: '$PLOT_OPTIONS'" >> "$ERROR_LOG"
    exit 1
fi

if [ "$PLOT_HDZ" = "true" ]; then
    if MAGNETOMETER_BASE_PATH="$BASE_PATH" su "$FILE_OWNER" -c "/usr/bin/gnuplot $BASE_PATH/scripts/PlotRollingHDZ.gp >> $MAIN_LOG 2>> $ERROR_LOG"; then
        log_msg "processRollingData.sh     : Completed rolling HDZ plot" >> "$MAIN_LOG"
    else
        log_msg "processRollingData.sh     : FAILED - look in log-error.txt for details" >> "$MAIN_LOG"
        log_msg "processRollingData.sh     : FAILED rolling HDZ plot" >> "$ERROR_LOG"
        exit 1
    fi
else
    log_msg "processRollingData.sh     : Skipping rolling HDZ plot (plot_hdz = false in plot.ini)" >> "$MAIN_LOG"
fi

if [ "$PLOT_BI" = "true" ]; then
    if MAGNETOMETER_BASE_PATH="$BASE_PATH" su "$FILE_OWNER" -c "/usr/bin/gnuplot $BASE_PATH/scripts/PlotRollingBI.gp >> $MAIN_LOG 2>> $ERROR_LOG"; then
        log_msg "processRollingData.sh     : Completed rolling BI plot" >> "$MAIN_LOG"
    else
        log_msg "processRollingData.sh     : FAILED - look in log-error.txt for details" >> "$MAIN_LOG"
        log_msg "processRollingData.sh     : FAILED rolling BI plot" >> "$ERROR_LOG"
        exit 1
    fi
else
    log_msg "processRollingData.sh     : Skipping rolling BI plot (plot_bi = false in plot.ini)" >> "$MAIN_LOG"
fi

if ! PLOT_KP=$(MAGNETOMETER_BASE_PATH="$BASE_PATH" /usr/bin/python3 "$BASE_PATH/scripts/GetKpOptions.py" 2>&1); then
    log_msg "processRollingData.sh     : FAILED to read Kp plot option: $PLOT_KP" >> "$ERROR_LOG"
    exit 1
fi

if [ "$PLOT_KP" != "true" ] && [ "$PLOT_KP" != "false" ]; then
    log_msg "processRollingData.sh     : FAILED - unexpected Kp plot option: '$PLOT_KP'" >> "$ERROR_LOG"
    exit 1
fi

if [ "$PLOT_NOAA" = "true" ] && [ ! -f "$BASE_PATH/temp/noaa/latest.jpg" ]; then
    log_msg "processRollingData.sh     : NOAA forecast enabled without cached data; refreshing now" >> "$MAIN_LOG"
    if ! MAGNETOMETER_BASE_PATH="$BASE_PATH" /bin/bash "$BASE_PATH/scripts/updateNoaaAuroraForecast.sh"; then
        log_msg "processRollingData.sh     : WARNING - immediate NOAA forecast refresh failed; will retry next cycle" >> "$ERROR_LOG"
    fi
fi

if [ "$PLOT_KP" = "true" ] && [ ! -f "$BASE_PATH/temp/kp/PlanetaryKp.png" ]; then
    log_msg "processRollingData.sh     : Kp forecast enabled without cached data; refreshing now" >> "$MAIN_LOG"
    if ! MAGNETOMETER_BASE_PATH="$BASE_PATH" /bin/bash "$BASE_PATH/scripts/updateKpForecast.sh"; then
        log_msg "processRollingData.sh     : WARNING - immediate Kp forecast refresh failed; will retry next cycle" >> "$ERROR_LOG"
    fi
fi

if MAGNETOMETER_BASE_PATH="$BASE_PATH" su "$FILE_OWNER" -c "/usr/bin/python3 $BASE_PATH/scripts/EvaluateAlerts.py >> $MAIN_LOG 2>> $ERROR_LOG"; then
    log_msg "processRollingData.sh     : Completed rolling alert evaluation" >> "$MAIN_LOG"
else
    log_msg "processRollingData.sh     : FAILED - look in log-error.txt for details" >> "$MAIN_LOG"
    log_msg "processRollingData.sh     : FAILED rolling alert evaluation" >> "$ERROR_LOG"
    exit 1
fi

if MAGNETOMETER_BASE_PATH="$BASE_PATH" /bin/bash "$BASE_PATH/scripts/publishWeb.sh"; then
    log_msg "processRollingData.sh     : Completed rolling publish" >> "$MAIN_LOG"

    if MAGNETOMETER_BASE_PATH="$BASE_PATH" /bin/bash "$BASE_PATH/scripts/uploadRemote.sh" rolling; then
        log_msg "processRollingData.sh     : Completed remote rolling upload" >> "$MAIN_LOG"
    else
        log_msg "processRollingData.sh     : FAILED - look in log-error.txt for details" >> "$MAIN_LOG"
        log_msg "processRollingData.sh     : FAILED remote rolling upload (local publish kept)" >> "$ERROR_LOG"
    fi
else
    log_msg "processRollingData.sh     : FAILED - look in log-error.txt for details" >> "$MAIN_LOG"
    log_msg "processRollingData.sh     : FAILED rolling publish" >> "$ERROR_LOG"
    exit 1
fi

log_msg "processRollingData.sh     : Completed rolling processing and publishing" >> "$MAIN_LOG"