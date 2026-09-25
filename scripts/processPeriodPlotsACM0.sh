#!/bin/bash

BASE_PATH=${MAGNETOMETER_BASE_PATH:-/home/pi/UKRAA_Magnetometer}
LOG_DIR="$BASE_PATH/logfiles"
MAIN_LOG="$LOG_DIR/log-MagnetometerACM0.txt"
ERROR_LOG="$LOG_DIR/log-error.txt"
STATUS_FILE="$BASE_PATH/data/status/period-plots.json"

log_msg() {
    printf '%s : %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1"
}

if ! MAGNETOMETER_BASE_PATH="$BASE_PATH" /usr/bin/python3 "$BASE_PATH/scripts/GetPeriodPlotAvailabilityACM0.py" --write-status >> "$MAIN_LOG" 2>> "$ERROR_LOG"; then
    log_msg "processPeriodPlotsACM0.sh : FAILED to write period plot availability" >> "$ERROR_LOG"
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

    if MAGNETOMETER_BASE_PATH="$BASE_PATH" MAGNETOMETER_PLOT_PERIOD="$period_name" \
        su pi -c "/usr/bin/gnuplot $BASE_PATH/scripts/$plot_script >> $MAIN_LOG 2>> $ERROR_LOG"; then
        log_msg "processPeriodPlotsACM0.sh : Completed $period_name $family_name plot" >> "$MAIN_LOG"
        return 0
    fi

    log_msg "processPeriodPlotsACM0.sh : FAILED $period_name $family_name plot" >> "$ERROR_LOG"
    return 1
}

for period_name in week month 3month 6month year; do
    enabled=$(period_value "$period_name" enabled) || exit 1
    available=$(period_value "$period_name" available) || exit 1

    for family_name in XYZ HDZ BI; do
        family_key=$(printf '%s' "$family_name" | tr '[:upper:]' '[:lower:]')
        family_enabled=$(family_value "$family_key") || exit 1
        temp_plot="$BASE_PATH/temp/periods/$period_name/$family_name.png"

        if [ "$enabled" = "True" ] && [ "$available" = "True" ] && [ "$family_enabled" = "True" ]; then
            case "$family_name" in
                XYZ) plot_script="PlotPeriodXYZACM0.gp" ;;
                HDZ) plot_script="PlotPeriodHDZACM0.gp" ;;
                BI) plot_script="PlotPeriodBIACM0.gp" ;;
            esac

            if ! render_period "$period_name" "$family_name" "$plot_script"; then
                exit 1
            fi
        else
            rm -f "$temp_plot"
            log_msg "processPeriodPlotsACM0.sh : Skipping $period_name $family_name plot" >> "$MAIN_LOG"
        fi
    done
done

log_msg "processPeriodPlotsACM0.sh : Completed period plot processing" >> "$MAIN_LOG"