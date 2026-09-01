#!/bin/bash

set -u

BASE_PATH=${MAGNETOMETER_BASE_PATH:-/home/pi/UKRAA_Magnetometer}
LOG_DIR="$BASE_PATH/logfiles"
MAIN_LOG="$LOG_DIR/log-MagnetometerACM0.txt"
ERROR_LOG="$LOG_DIR/log-error.txt"
NOAA_URL=${MAGNETOMETER_NOAA_AURORA_URL:-https://services.swpc.noaa.gov/images/animations/ovation/north/latest.jpg}
NOAA_DIR="$BASE_PATH/temp/noaa"
NOAA_IMAGE="$NOAA_DIR/latest.jpg"

log_msg() {
    printf '%s : %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1"
}

mkdir -p "$NOAA_DIR" "$LOG_DIR"

log_msg "updateNoaaAuroraForecast.sh : Started NOAA aurora forecast update" >> "$MAIN_LOG"

DOWNLOAD_OUTPUT=$(mktemp)

if /usr/bin/python3 - "$NOAA_URL" "$NOAA_IMAGE" > "$DOWNLOAD_OUTPUT" 2>&1 <<'PY'
import os
import sys
import tempfile
import urllib.error
import urllib.request

try:
    import grp
    import pwd
except ImportError:
    grp = None
    pwd = None


def set_output_permissions(output_path):
    os.chmod(output_path, 0o644)

    if grp is None or pwd is None:
        return

    if not hasattr(os, 'geteuid') or os.geteuid() != 0:
        return

    owner_name = os.environ.get('MAGNETOMETER_FILE_OWNER', 'pi')
    try:
        owner = pwd.getpwnam(owner_name)
        group = grp.getgrnam(owner_name)
    except KeyError:
        print(f'INFO: File owner {owner_name} not found, leaving current ownership')
        return

    os.chown(output_path, owner.pw_uid, group.gr_gid)


def download_forecast(url, output_path):
    output_dir = os.path.dirname(output_path)
    os.makedirs(output_dir, exist_ok=True)

    fd, temp_path = tempfile.mkstemp(prefix='.latest-', suffix='.jpg.tmp', dir=output_dir)
    os.close(fd)

    try:
        request = urllib.request.Request(url, headers={'User-Agent': 'UKRAA-Magnetometer/1.0'})
        with urllib.request.urlopen(request, timeout=30) as response:
            content_type = response.headers.get('Content-Type', '')
            data = response.read()

        if len(data) == 0:
            print('ERROR: NOAA download returned an empty file')
            return 1

        if not data.startswith(b'\xff\xd8'):
            print('ERROR: NOAA download did not look like a JPEG image')
            return 1

        with open(temp_path, 'wb') as output_file:
            output_file.write(data)

        os.replace(temp_path, output_path)
        set_output_permissions(output_path)
        print(f'INFO: Downloaded NOAA aurora forecast image ({len(data)} bytes, {content_type})')
        return 0
    except (OSError, urllib.error.URLError) as exc:
        print('ERROR: NOAA download failed: ' + str(exc))
        return 1
    finally:
        if os.path.exists(temp_path):
            os.remove(temp_path)


def main():
    if len(sys.argv) != 3:
        print('ERROR: Internal argument error')
        return 2

    return download_forecast(sys.argv[1], sys.argv[2])


if __name__ == '__main__':
    raise SystemExit(main())
PY
then
    while IFS= read -r line; do
        if [ -n "$line" ]; then
            log_msg "updateNoaaAuroraForecast.sh : ${line#INFO: }" >> "$MAIN_LOG"
        fi
    done < "$DOWNLOAD_OUTPUT"

    rm -f "$DOWNLOAD_OUTPUT"
    log_msg "updateNoaaAuroraForecast.sh : Completed NOAA aurora forecast update" >> "$MAIN_LOG"
    exit 0
fi

while IFS= read -r line; do
    if [ -n "$line" ]; then
        log_msg "updateNoaaAuroraForecast.sh : FAILED - ${line#ERROR: }" >> "$ERROR_LOG"
    fi
done < "$DOWNLOAD_OUTPUT"

rm -f "$DOWNLOAD_OUTPUT"
log_msg "updateNoaaAuroraForecast.sh : FAILED NOAA aurora forecast update" >> "$ERROR_LOG"
exit 1
