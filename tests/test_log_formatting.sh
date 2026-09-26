#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../scripts" && pwd)
source "$SCRIPT_DIR/logging.sh"

short_entry=$(write_log_entry 'ProcessRolling.py     : Started processing')
long_entry=$(write_log_entry 'updateNoaaAuroraForecast.sh : Started update')

if [ "${short_entry:50:1}" != ':' ] || [ "${long_entry:50:1}" != ':' ]; then
    echo 'LOG_FORMAT: FAIL - second colon is not in column 51'
    exit 1
fi

if [ "${#long_entry}" -lt 53 ]; then
    echo 'LOG_FORMAT: FAIL - message field is missing'
    exit 1
fi

echo 'LOG_FORMAT: PASS - source field is 27 characters wide'