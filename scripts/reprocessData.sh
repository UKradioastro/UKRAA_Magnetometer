#!/bin/bash

# script reprocessData.sh to rebuild processed data from the raw data archive.
# Use after a software update that changes processing, or after copying older
# raw data files back onto the system. Regenerates minute data, hourly data
# and daily summaries for every raw day in range, then refreshes the
# week-to-year period plots.

set -u

source "$(dirname "${BASH_SOURCE[0]}")/magnetometer-env.sh"
LOG_DIR="$BASE_PATH/logfiles"
MAIN_LOG="$LOG_DIR/log-Magnetometer.txt"
ERROR_LOG="$LOG_DIR/log-error.txt"

source "$(dirname "${BASH_SOURCE[0]}")/logging.sh"

log_msg() {
    write_log_entry "$1"
}

usage() {
    cat <<EOF
Usage: sudo bash $0 [options]

Rebuilds minute, hourly and daily summary data from raw data files, then
refreshes the period (week to year) plots.

Options:
  --from YYYY-MM-DD    First day to reprocess (default: oldest raw file)
  --to YYYY-MM-DD      Last day to reprocess (default: yesterday)
  --skip-hourly        Do not rebuild hourly data
  --skip-period-plots  Do not regenerate period plots after reprocessing
  --publish            Run moveGraphs.sh afterwards to publish plots to the web page
  --dry-run            List the days that would be reprocessed and exit
  --help               Show this help

Existing minute and hourly files for each reprocessed day are overwritten.
Today's partial raw file is never reprocessed.
EOF
}

valid_date() {
    [[ "$1" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] && date -d "$1" '+%Y-%m-%d' >/dev/null 2>&1
}

FROM_DATE=""
TO_DATE=$(date -d yesterday +%Y-%m-%d)
RUN_HOURLY=true
RUN_PERIOD_PLOTS=true
RUN_PUBLISH=false
DRY_RUN=false

while [ "$#" -gt 0 ]; do
    case "$1" in
        --from)
            FROM_DATE=${2:-}
            shift 2 || { usage; exit 2; }
            ;;
        --to)
            TO_DATE=${2:-}
            shift 2 || { usage; exit 2; }
            ;;
        --skip-hourly) RUN_HOURLY=false; shift ;;
        --skip-period-plots) RUN_PERIOD_PLOTS=false; shift ;;
        --publish) RUN_PUBLISH=true; shift ;;
        --dry-run) DRY_RUN=true; shift ;;
        --help|-h) usage; exit 0 ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 2
            ;;
    esac
done

if [ -n "$FROM_DATE" ] && ! valid_date "$FROM_DATE"; then
    echo "Invalid --from date: $FROM_DATE (expected YYYY-MM-DD)"
    exit 2
fi

if ! valid_date "$TO_DATE"; then
    echo "Invalid --to date: $TO_DATE (expected YYYY-MM-DD)"
    exit 2
fi

TODAY=$(date +%Y-%m-%d)
if [[ ! "$TO_DATE" < "$TODAY" ]]; then
    TO_DATE=$(date -d yesterday +%Y-%m-%d)
    echo "Limiting --to to $TO_DATE (today's raw file is still being written)"
fi

if [ -n "$FROM_DATE" ] && [[ "$FROM_DATE" > "$TO_DATE" ]]; then
    echo "--from ($FROM_DATE) is after --to ($TO_DATE)"
    exit 2
fi

RAW_ROOT="$BASE_PATH/data/raw"
TARGET_DATES=()
if [ -d "$RAW_ROOT" ]; then
    # ISO dates sort and compare correctly as plain strings
    while IFS= read -r raw_file; do
        day=$(basename "$raw_file" .csv)
        # ignore renamed copies such as 2026-05-01_old.csv
        if ! valid_date "$day"; then
            echo "Ignoring raw file that is not named YYYY-MM-DD.csv: $raw_file"
            continue
        fi
        if [ -n "$FROM_DATE" ] && [[ "$day" < "$FROM_DATE" ]]; then
            continue
        fi
        if [[ "$day" > "$TO_DATE" ]]; then
            continue
        fi
        TARGET_DATES+=("$day")
    done < <(find "$RAW_ROOT" -mindepth 3 -maxdepth 3 -type f \
        -regextype posix-extended -regex '.*/[0-9]{4}-[0-9]{2}-[0-9]{2}\.csv' -printf '%f\n' | sort -u)
fi

if [ "${#TARGET_DATES[@]}" -eq 0 ]; then
    echo "No raw data files found in $RAW_ROOT for the requested range"
    exit 1
fi

echo "Days to reprocess: ${#TARGET_DATES[@]} (${TARGET_DATES[0]} to ${TARGET_DATES[-1]})"

if [ "$DRY_RUN" = "true" ]; then
    printf '%s\n' "${TARGET_DATES[@]}"
    exit 0
fi

if [ "$(id -u)" -ne 0 ]; then
    echo "Please run with sudo: sudo bash $0 $*"
    exit 1
fi

run_as_owner() {
    su "$FILE_OWNER" -c "MAGNETOMETER_BASE_PATH='$BASE_PATH' $1 >> '$MAIN_LOG' 2>> '$ERROR_LOG'"
}

log_msg "reprocessData.sh          : Started reprocessing ${#TARGET_DATES[@]} day(s) from ${TARGET_DATES[0]} to ${TARGET_DATES[-1]}" >> "$MAIN_LOG"

FAILURES=0
COUNT=0
TOTAL=${#TARGET_DATES[@]}

for day in "${TARGET_DATES[@]}"; do
    COUNT=$((COUNT + 1))
    printf '[%d/%d] %s\n' "$COUNT" "$TOTAL" "$day"

    if ! run_as_owner "MAGNETOMETER_TARGET_DATE='$day' /usr/bin/python3 '$BASE_PATH/scripts/ProcessDataRaw.py'"; then
        log_msg "reprocessData.sh          : FAILED minute data for $day" >> "$ERROR_LOG"
        FAILURES=$((FAILURES + 1))
        continue
    fi

    if [ "$RUN_HOURLY" = "true" ]; then
        if ! run_as_owner "MAGNETOMETER_TARGET_DATE='$day' /usr/bin/python3 '$BASE_PATH/scripts/ProcessDataHour.py'"; then
            log_msg "reprocessData.sh          : FAILED hourly data for $day" >> "$ERROR_LOG"
            FAILURES=$((FAILURES + 1))
        fi
    fi
done

# --all rebuilds every per-day summary from minute data and the combined summary.csv once
if run_as_owner "/usr/bin/python3 '$BASE_PATH/scripts/ProcessDailySummary.py' --all"; then
    log_msg "reprocessData.sh          : Completed daily summary rebuild" >> "$MAIN_LOG"
else
    log_msg "reprocessData.sh          : FAILED daily summary rebuild" >> "$ERROR_LOG"
    FAILURES=$((FAILURES + 1))
fi

if [ "$RUN_PERIOD_PLOTS" = "true" ]; then
    if MAGNETOMETER_BASE_PATH="$BASE_PATH" /bin/bash "$BASE_PATH/scripts/processPeriodPlots.sh"; then
        log_msg "reprocessData.sh          : Completed period plotting" >> "$MAIN_LOG"
    else
        log_msg "reprocessData.sh          : FAILED period plotting" >> "$ERROR_LOG"
        FAILURES=$((FAILURES + 1))
    fi
fi

if [ "$RUN_PUBLISH" = "true" ]; then
    if MAGNETOMETER_BASE_PATH="$BASE_PATH" /bin/bash "$BASE_PATH/scripts/moveGraphs.sh"; then
        log_msg "reprocessData.sh          : Completed publish" >> "$MAIN_LOG"
    else
        log_msg "reprocessData.sh          : FAILED publish" >> "$ERROR_LOG"
        FAILURES=$((FAILURES + 1))
    fi
fi

if [ "$FAILURES" -gt 0 ]; then
    log_msg "reprocessData.sh          : Completed reprocessing with $FAILURES failure(s)" >> "$MAIN_LOG"
    echo "Reprocessing finished with $FAILURES failure(s) - see $ERROR_LOG"
    exit 1
fi

log_msg "reprocessData.sh          : Completed reprocessing ${#TARGET_DATES[@]} day(s)" >> "$MAIN_LOG"
echo "Reprocessing complete - see $MAIN_LOG"
