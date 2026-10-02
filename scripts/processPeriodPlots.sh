#!/bin/bash

source "$(dirname "${BASH_SOURCE[0]}")/magnetometer-env.sh"
LOG_DIR="$BASE_PATH/logfiles"
MAIN_LOG="$LOG_DIR/log-Magnetometer.txt"
ERROR_LOG="$LOG_DIR/log-error.txt"
STATUS_FILE="$BASE_PATH/data/status/period-plots.json"

source "$(dirname "${BASH_SOURCE[0]}")/logging.sh"

log_msg() {
    write_log_entry "$1"
}

if ! SPACEWEATHER_OPTION=$(/usr/bin/python3 "$BASE_PATH/scripts/GetPeriodSpaceWeatherOption.py" 2>&1); then
    log_msg "processPeriodPlots.sh : FAILED to read space-weather plot option: $SPACEWEATHER_OPTION" >> "$ERROR_LOG"
    exit 1
fi
if [ "$SPACEWEATHER_OPTION" != "true" ] && [ "$SPACEWEATHER_OPTION" != "false" ]; then
    log_msg "processPeriodPlots.sh : FAILED - unexpected space-weather option: '$SPACEWEATHER_OPTION'" >> "$ERROR_LOG"
    exit 1
fi

PERIOD_TARGET_DATE=${MAGNETOMETER_TARGET_DATE:-$(date -d yesterday +%Y-%m-%d)}

if ! MAGNETOMETER_BASE_PATH="$BASE_PATH" /usr/bin/python3 "$BASE_PATH/scripts/GetPeriodPlotAvailability.py" --write-status > /dev/null 2>> "$ERROR_LOG"; then
    log_msg "processPeriodPlots.sh : FAILED to write period plot availability" >> "$ERROR_LOG"
    exit 1
fi

period_value() {
    /usr/bin/python3 -c "import json; import sys; print(json.load(open(sys.argv[1], encoding='UTF-8'))['periods'][sys.argv[2]][sys.argv[3]])" "$STATUS_FILE" "$1" "$2"
}

family_value() {
    /usr/bin/python3 -c "import json; import sys; print(json.load(open(sys.argv[1], encoding='UTF-8'))['families'][sys.argv[2]])" "$STATUS_FILE" "$1"
}

render_period() {
    local period_name=$1
    local family_name=$2
    local plot_script=$3
    local command

    if [ "$SPACEWEATHER_OPTION" = "true" ]; then
        command="MAGNETOMETER_BASE_PATH='$BASE_PATH' /usr/bin/python3 '$BASE_PATH/scripts/PlotPeriodSpaceWeather.py' --period '$period_name' --family '$family_name' --target-date '$PERIOD_TARGET_DATE'"
    else
        command="MAGNETOMETER_BASE_PATH='$BASE_PATH' MAGNETOMETER_PLOT_PERIOD='$period_name' /usr/bin/gnuplot '$BASE_PATH/scripts/$plot_script'"
    fi

    if su "$FILE_OWNER" -c "$command >> '$MAIN_LOG' 2>> '$ERROR_LOG'"; then
        log_msg "processPeriodPlots.sh : Completed $period_name $family_name plot" >> "$MAIN_LOG"
        return 0
    fi

    log_msg "processPeriodPlots.sh : FAILED $period_name $family_name plot" >> "$ERROR_LOG"
    return 1
}

if [ "$SPACEWEATHER_OPTION" = "true" ]; then
    if su "$FILE_OWNER" -c "MAGNETOMETER_BASE_PATH='$BASE_PATH' /usr/bin/python3 '$BASE_PATH/scripts/UpdatePeriodSpaceWeather.py' --end-date '$PERIOD_TARGET_DATE' >> '$MAIN_LOG' 2>> '$ERROR_LOG'"; then
        log_msg "processPeriodPlots.sh : Refreshed historical space-weather data" >> "$MAIN_LOG"
    else
        log_msg "processPeriodPlots.sh : WARNING - space-weather refresh failed; using cached data if available" >> "$MAIN_LOG"
        log_msg "processPeriodPlots.sh : Space-weather refresh failed; period plots will continue" >> "$ERROR_LOG"
    fi
fi

PERIOD_FAILURES=0

for period_name in week month 3month 6month year; do
    enabled=$(period_value "$period_name" enabled) || exit 1
    available=$(period_value "$period_name" available) || exit 1

    for family_name in XYZ HDZ BI; do
        family_key=$(printf '%s' "$family_name" | tr '[:upper:]' '[:lower:]')
        family_enabled=$(family_value "$family_key") || exit 1
        temp_plot="$BASE_PATH/temp/periods/$period_name/$family_name.png"

        if [ "$enabled" = "True" ] && [ "$available" = "True" ] && [ "$family_enabled" = "True" ]; then
            case "$family_name" in
                XYZ) plot_script="PlotPeriodXYZ.gp" ;;
                HDZ) plot_script="PlotPeriodHDZ.gp" ;;
                BI) plot_script="PlotPeriodBI.gp" ;;
            esac

            if ! render_period "$period_name" "$family_name" "$plot_script"; then
                PERIOD_FAILURES=$((PERIOD_FAILURES + 1))
            fi
        else
            rm -f "$temp_plot"
            log_msg "processPeriodPlots.sh : Skipping $period_name $family_name plot" >> "$MAIN_LOG"
        fi
    done
done

if [ "$PERIOD_FAILURES" -gt 0 ]; then
    log_msg "processPeriodPlots.sh : Completed period plot processing with $PERIOD_FAILURES failure(s)" >> "$MAIN_LOG"
    exit 1
fi

log_msg "processPeriodPlots.sh : Completed period plot processing" >> "$MAIN_LOG"