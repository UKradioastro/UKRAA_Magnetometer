#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../scripts" && pwd)
TEST_ROOT=$(mktemp -d)
trap 'rm -rf "$TEST_ROOT"' EXIT

fail() {
    echo "UPDATE_MAGNETOMETER: FAIL - $1"
    if [ -n "${output:-}" ]; then
        printf '%s\n' "$output"
    fi
    exit 1
}

# Mock privileged and network operations; all file writes stay in TEST_ROOT.
id() {
    case "$1" in
        -u) echo 0 ;;
        -gn) echo testgroup ;;
        *) echo "Unexpected id arguments: $*" >&2; return 1 ;;
    esac
}

stat() {
    echo testuser
}

chown() {
    return 0
}

install() {
    local args=()
    while [ "$#" -gt 0 ]; do
        case "$1" in
            -o|-g) shift 2 ;;
            *) args+=("$1"); shift ;;
        esac
    done
    command install "${args[@]}"
}

curl() {
    if [ "${TEST_DOWNLOAD_STATUS:-0}" -ne 0 ]; then
        echo "Simulated download failure" >&2
        return "$TEST_DOWNLOAD_STATUS"
    fi
    if [ "$1" = "-fsSL" ]; then
        printf 'worker:%s\n' "${BASH_SOURCE[1]}" >> "$TEST_CALLS"
        printf '{"tag_name":"%s"}\n' "$TEST_RELEASE_TAG"
    else
        echo download >> "$TEST_CALLS"
        while [ "$#" -gt 0 ]; do
            if [ "$1" = "-o" ]; then
                : > "$2"
                return 0
            fi
            shift
        done
        echo "Missing archive output path" >&2
        return 1
    fi
}

unzip() {
    command cp -a "$TEST_RELEASE_DIR" "$4/release"
}

cp() {
    command cp "$@" || return $?
    if [ "${TEST_COPY_STATUS:-0}" -ne 0 ] && [[ "$*" == *"/release/scripts/."* ]]; then
        echo "Simulated partial copy failure" >&2
        return "$TEST_COPY_STATUS"
    fi
}

export -f id stat chown install curl unzip cp

# BASH_ENV also supplies the absolute Python command on hosts without Linux Python.
cat > "$TEST_ROOT/mock-json.sh" <<'EOF'
/usr/bin/python3() {
    cat > /dev/null
    printf '%s\n' "$TEST_RELEASE_TAG"
}
EOF
export BASH_ENV="$TEST_ROOT/mock-json.sh"
export TEST_RELEASE_TAG=2026.10.1

setup_case() {
    local name=$1
    export MAGNETOMETER_BASE_PATH="$TEST_ROOT/$name/installation"
    export MAGNETOMETER_FILE_OWNER=testuser
    export TEST_RELEASE_DIR="$TEST_ROOT/$name/fixture"
    export TEST_CALLS="$TEST_ROOT/$name/calls"
    export TMPDIR="$TEST_ROOT/$name/temporary"
    export TEST_COPY_STATUS=0 TEST_DOWNLOAD_STATUS=0
    export TEST_INSTALL_STATUS=0 TEST_CHECK_STATUS=0
    mkdir -p "$MAGNETOMETER_BASE_PATH"/{scripts,config,data,logfiles} \
        "$TEST_RELEASE_DIR"/{scripts,install} "$TMPDIR"
    command cp "$SCRIPT_DIR/updateMagnetometer.sh" "$SCRIPT_DIR/magnetometer-env.sh" \
        "$MAGNETOMETER_BASE_PATH/scripts/"
    echo 2026.10.0 > "$MAGNETOMETER_BASE_PATH/VERSION"
    echo 2026.10.0 > "$MAGNETOMETER_BASE_PATH/config/installed-version.txt"
    echo recorded-data > "$MAGNETOMETER_BASE_PATH/data/recorded.csv"
    echo site-specific > "$MAGNETOMETER_BASE_PATH/config/site.ini"
    echo existing-log > "$MAGNETOMETER_BASE_PATH/logfiles/site.log"
    : > "$TEST_CALLS"
    printf '%s\n' "$TEST_RELEASE_TAG" > "$TEST_RELEASE_DIR/VERSION"

    # A much longer replacement catches Bash reads at stale offsets in the launcher.
    for ((i = 0; i < 300; i++)); do
        echo "# Incoming release padding $i"
    done > "$TEST_RELEASE_DIR/scripts/updateMagnetometer.sh"
    cat "$SCRIPT_DIR/updateMagnetometer.sh" >> "$TEST_RELEASE_DIR/scripts/updateMagnetometer.sh"
    command cp "$SCRIPT_DIR/magnetometer-env.sh" "$TEST_RELEASE_DIR/scripts/"
    cat > "$TEST_RELEASE_DIR/install/install.sh" <<'EOF'
#!/bin/bash
set -euo pipefail
echo installer >> "$TEST_CALLS"
if [ "$TEST_INSTALL_STATUS" -ne 0 ]; then
    echo "Simulated installer failure" >&2
    exit "$TEST_INSTALL_STATUS"
fi
cat "$MAGNETOMETER_BASE_PATH/VERSION" > "$MAGNETOMETER_BASE_PATH/config/installed-version.txt"
EOF
    cat > "$TEST_RELEASE_DIR/scripts/runPostUpdateChecks.sh" <<'EOF'
#!/bin/bash
echo checks >> "$TEST_CALLS"
if [ "$TEST_CHECK_STATUS" -ne 0 ]; then
    echo "POST_UPDATE_CHECKS: FAIL"
    exit "$TEST_CHECK_STATUS"
fi
echo "POST_UPDATE_CHECKS: PASS"
EOF
}

run_updater() {
    local expected_status=$1
    local script_path=${2:-$MAGNETOMETER_BASE_PATH/scripts/updateMagnetometer.sh}
    local status
    if output=$(bash "$script_path" 2>&1); then
        status=0
    else
        status=$?
    fi
    [ "$status" -eq "$expected_status" ] || fail "expected exit $expected_status, got $status"
    [ -z "$(find "$TMPDIR" -mindepth 1 -print -quit)" ] || fail "temporary update files remain"
    [ "$(cat "$MAGNETOMETER_BASE_PATH/data/recorded.csv")" = recorded-data ] || fail "data changed"
    [ "$(cat "$MAGNETOMETER_BASE_PATH/config/site.ini")" = site-specific ] || fail "config changed"
    [ "$(cat "$MAGNETOMETER_BASE_PATH/logfiles/site.log")" = existing-log ] || fail "log changed"
    grep -Fq "worker:$TMPDIR/" "$TEST_CALLS" || fail "update did not run from a temporary copy"
}

assert_installed() {
    [ "$(cat "$MAGNETOMETER_BASE_PATH/VERSION")" = "$TEST_RELEASE_TAG" ] || fail "code version not updated"
    [ "$(cat "$MAGNETOMETER_BASE_PATH/config/installed-version.txt")" = "$TEST_RELEASE_TAG" ] || fail "installation not completed"
    cmp -s "$TEST_RELEASE_DIR/scripts/updateMagnetometer.sh" \
        "$MAGNETOMETER_BASE_PATH/scripts/updateMagnetometer.sh" || fail "updater not replaced"
    grep -qx installer "$TEST_CALLS" || fail "installer did not run"
    grep -qx checks "$TEST_CALLS" || fail "post-update checks did not run"
    [[ "$output" == *"POST_UPDATE_CHECKS: PASS"* ]] || fail "missing success result"
}

setup_case self-replacement
run_updater 0
assert_installed
echo "PASS: self-replacement and cleanup"

: > "$TEST_CALLS"
run_updater 0
[ "$(wc -l < "$TEST_CALLS")" -eq 1 ] || fail "current installation downloaded or installed again"
[[ "$output" == *"already up to date"* ]] || fail "missing current-version result"
echo "PASS: already current"

export TEST_RELEASE_TAG=2026.10.2
printf '%s\n' "$TEST_RELEASE_TAG" > "$TEST_RELEASE_DIR/VERSION"
command cp "$SCRIPT_DIR/updateMagnetometer.sh" "$TEST_RELEASE_DIR/scripts/"
: > "$TEST_CALLS"
run_updater 0
assert_installed
echo "PASS: replacement by a shorter updater"
export TEST_RELEASE_TAG=2026.10.1

setup_case interrupted-install
command cp -a "$TEST_RELEASE_DIR/install" "$MAGNETOMETER_BASE_PATH/"
command cp "$TEST_RELEASE_DIR/scripts/runPostUpdateChecks.sh" "$MAGNETOMETER_BASE_PATH/scripts/"
echo "$TEST_RELEASE_TAG" > "$MAGNETOMETER_BASE_PATH/VERSION"
run_updater 0
grep -qx installer "$TEST_CALLS" || fail "interrupted installer was not retried"
grep -qx checks "$TEST_CALLS" || fail "retry did not run post-update checks"
! grep -qx download "$TEST_CALLS" || fail "current code was downloaded again"
[ "$(cat "$MAGNETOMETER_BASE_PATH/config/installed-version.txt")" = "$TEST_RELEASE_TAG" ] || fail "retry did not complete"
echo "PASS: interrupted-install retry"

setup_case copy-failure
export TEST_COPY_STATUS=23
run_updater 23
[ "$(cat "$MAGNETOMETER_BASE_PATH/VERSION")" = 2026.10.0 ] || fail "partial copy advanced VERSION"
! grep -qx installer "$TEST_CALLS" || fail "installer ran after copy failure"
export TEST_COPY_STATUS=0
run_updater 0
assert_installed
echo "PASS: partial copy failure and retry"

setup_case installer-failure
export TEST_INSTALL_STATUS=24
run_updater 24
[ "$(cat "$MAGNETOMETER_BASE_PATH/config/installed-version.txt")" = 2026.10.0 ] || fail "failed installer advanced marker"
! grep -qx checks "$TEST_CALLS" || fail "checks ran after installer failure"
export TEST_INSTALL_STATUS=0
: > "$TEST_CALLS"
run_updater 0
assert_installed
! grep -qx download "$TEST_CALLS" || fail "installer retry downloaded current code"
echo "PASS: installer failure and retry"

setup_case check-failure
export TEST_CHECK_STATUS=25
run_updater 25
grep -qx checks "$TEST_CALLS" || fail "checks were skipped"
[[ "$output" == *"POST_UPDATE_CHECKS: FAIL"* ]] || fail "check failure was not reported"
echo "PASS: post-update check failure"

setup_case download-failure
export TEST_DOWNLOAD_STATUS=22
if output=$(bash "$MAGNETOMETER_BASE_PATH/scripts/updateMagnetometer.sh" 2>&1); then
    fail "download failure was ignored"
else
    [ "$?" -eq 22 ] || fail "download failure status not preserved"
fi
[ -z "$(find "$TMPDIR" -mindepth 1 -print -quit)" ] || fail "download failure left temporary files"
[ "$(cat "$MAGNETOMETER_BASE_PATH/VERSION")" = 2026.10.0 ] || fail "download failure advanced VERSION"
echo "PASS: download failure"

setup_case external-updater
command cp "$SCRIPT_DIR/updateMagnetometer.sh" "$TEST_ROOT/recovery.sh"
run_updater 0 "$TEST_ROOT/recovery.sh"
assert_installed
echo "PASS: external updater without colocated environment"

echo "UPDATE_MAGNETOMETER: PASS"
