#!/bin/bash

set -u

BASE_PATH=${MAGNETOMETER_BASE_PATH:-/home/pi/UKRAA_Magnetometer}
LOG_DIR="$BASE_PATH/logfiles"
MAIN_LOG="$LOG_DIR/log-MagnetometerACM0.txt"
ERROR_LOG="$LOG_DIR/log-error.txt"
KP_DATA="$BASE_PATH/data/kp/latest.csv"
KP_TEMP="$BASE_PATH/temp/kp/PlanetaryKp.png"
KP_URL=${MAGNETOMETER_KP_FORECAST_URL:-https://services.swpc.noaa.gov/products/noaa-planetary-k-index-forecast.json}

log_msg() {
    printf '%s : %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1"
}

mkdir -p "$LOG_DIR"

# Repair output paths created by earlier root-run versions before switching to pi.
if [ "$(id -u)" -eq 0 ]; then
    mkdir -p "$BASE_PATH/data/kp" "$BASE_PATH/temp/kp" "$BASE_PATH/plots/kp"
    chown -R pi:pi "$BASE_PATH/data/kp" "$BASE_PATH/temp/kp" "$BASE_PATH/plots/kp"
fi

if ! PLOT_KP=$(MAGNETOMETER_BASE_PATH="$BASE_PATH" /usr/bin/python3 "$BASE_PATH/scripts/GetKpOptionsACM0.py" 2>&1); then
    log_msg "updateKpForecastACM0.sh    : FAILED to read Kp plot option: $PLOT_KP" >> "$ERROR_LOG"
    exit 1
fi

if [ "$PLOT_KP" != "true" ] && [ "$PLOT_KP" != "false" ]; then
    log_msg "updateKpForecastACM0.sh    : FAILED - unexpected Kp plot option: '$PLOT_KP'" >> "$ERROR_LOG"
    exit 1
fi

if [ "$PLOT_KP" = "false" ]; then
    rm -f "$KP_DATA" "$KP_TEMP"
    log_msg "updateKpForecastACM0.sh    : Planetary Kp forecast disabled (plot_kp=false)" >> "$MAIN_LOG"
    exit 0
fi

log_msg "updateKpForecastACM0.sh    : Started NOAA planetary Kp forecast update" >> "$MAIN_LOG"
if ! DOWNLOAD_OUTPUT=$(MAGNETOMETER_BASE_PATH="$BASE_PATH" su pi -c "/usr/bin/python3 $BASE_PATH/scripts/UpdateKpForecastACM0.py $KP_URL $KP_DATA" 2>&1); then
    log_msg "updateKpForecastACM0.sh    : FAILED - $DOWNLOAD_OUTPUT" >> "$ERROR_LOG"
    exit 1
fi

if MAGNETOMETER_BASE_PATH="$BASE_PATH" su pi -c "/usr/bin/gnuplot $BASE_PATH/scripts/PlotKpForecastACM0.gp >> $MAIN_LOG 2>> $ERROR_LOG"; then
    log_msg "updateKpForecastACM0.sh    : $DOWNLOAD_OUTPUT" >> "$MAIN_LOG"
    log_msg "updateKpForecastACM0.sh    : Completed NOAA planetary Kp forecast update" >> "$MAIN_LOG"
    exit 0
fi

log_msg "updateKpForecastACM0.sh    : FAILED rendering planetary Kp forecast" >> "$ERROR_LOG"
exit 1