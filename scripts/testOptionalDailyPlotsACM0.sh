#!/bin/bash

set -u

# The installer deletes its own directory, so a leftover cwd can break child shells.
cd / || exit 1

BASE_PATH=${MAGNETOMETER_BASE_PATH:-/home/pi/UKRAA_Magnetometer}
# Kept outside temp/ because moveGraphs.sh copies all of temp/ to the web root.
TEST_ROOT=${1:-"$BASE_PATH/tests/optional-daily-plots"}
TEST_BASE_PATH="$TEST_ROOT/UKRAA_Magnetometer"

if [ "${1:-}" = "--help" ]; then
    echo "Usage: $0 [TEST_ROOT]"
    echo "  Runs optional HDZ/BI daily publish tests against a temporary sandbox."
    echo "  Default TEST_ROOT: $BASE_PATH/tests/optional-daily-plots"
    exit 0
fi

log() {
    printf '%s\n' "$1"
}

fail() {
    printf 'FAIL: %s\n' "$1"
    exit 1
}

run_case() {
    local case_name=$1
    local plot_hdz=$2
    local plot_bi=$3
    local create_hdz=$4
    local create_bi=$5
    local expected_exit=$6

    local case_dir="$TEST_ROOT/$case_name"
    local scripts_dir="$case_dir/scripts"
    local temp_dir="$case_dir/temp"
    local config_dir="$case_dir/config"

    rm -rf "$case_dir"
    mkdir -p "$scripts_dir" "$temp_dir" "$config_dir"

    sed 's/\r$//' "$BASE_PATH/scripts/moveGraphs.sh" > "$scripts_dir/moveGraphs.sh"
    chmod +x "$scripts_dir/moveGraphs.sh"

    if ! /bin/bash -n "$scripts_dir/moveGraphs.sh"; then
        fail "$case_name moveGraphs.sh failed syntax check (possible upload/line-ending issue)"
    fi

    cat > "$scripts_dir/GetPlotOptionsACM0.py" <<PY
#!/usr/bin/env python3
print("$plot_hdz $plot_bi")
PY
    chmod +x "$scripts_dir/GetPlotOptionsACM0.py"

    touch "$temp_dir/Activity.png" "$temp_dir/XYZ.png"

    if [ "$create_hdz" = "true" ]; then
        touch "$temp_dir/HDZ.png"
    fi

    if [ "$create_bi" = "true" ]; then
        touch "$temp_dir/BI.png"
    fi

    mkdir -p "$TEST_BASE_PATH/logfiles" "$TEST_BASE_PATH/scripts" "$TEST_BASE_PATH/temp"
    cp "$scripts_dir/moveGraphs.sh" "$TEST_BASE_PATH/scripts/moveGraphs.sh"
    cp "$scripts_dir/GetPlotOptionsACM0.py" "$TEST_BASE_PATH/scripts/GetPlotOptionsACM0.py"

    rm -rf "$TEST_BASE_PATH/temp"
    cp -a "$temp_dir" "$TEST_BASE_PATH/temp"

    local host_html="$case_dir/var-www-html"
    mkdir -p "$host_html"

    local upload_stub="$TEST_BASE_PATH/scripts/uploadRemoteACM0.sh"
    cat > "$upload_stub" <<'UPLOAD'
#!/bin/bash
exit 0
UPLOAD
    chmod +x "$upload_stub"

    local case_run_log="$case_dir/moveGraphs-output.log"
    MAGNETOMETER_BASE_PATH="$TEST_BASE_PATH" MAGNETOMETER_WEB_ROOT="$host_html" /bin/bash "$TEST_BASE_PATH/scripts/moveGraphs.sh" >"$case_run_log" 2>&1
    local exit_code=$?

    if [ "$exit_code" -ne "$expected_exit" ]; then
        log "--- debug: moveGraphs output ($case_name) ---"
        cat "$case_run_log"
        log "--- debug: main log tail ($case_name) ---"
        tail -n 20 "$TEST_BASE_PATH/logfiles/log-MagnetometerACM0.txt" 2>/dev/null || true
        log "--- debug: error log tail ($case_name) ---"
        tail -n 20 "$TEST_BASE_PATH/logfiles/log-error.txt" 2>/dev/null || true
        fail "$case_name expected exit $expected_exit, got $exit_code"
    fi

    log "PASS: $case_name (exit $exit_code)"
}

rm -rf "$TEST_ROOT"
mkdir -p "$TEST_ROOT"

run_case "hdz_on_bi_on_all_present" "true" "true" "true" "true" 0
run_case "hdz_on_bi_on_bi_missing" "true" "true" "true" "false" 1
run_case "hdz_on_bi_off" "true" "false" "true" "false" 0
run_case "hdz_off_bi_on" "false" "true" "false" "true" 0
run_case "hdz_off_bi_off" "false" "false" "false" "false" 0
run_case "hdz_on_hdz_missing" "true" "false" "false" "false" 1

log "All optional daily plot publish tests passed."
log "Test root: $TEST_ROOT"
