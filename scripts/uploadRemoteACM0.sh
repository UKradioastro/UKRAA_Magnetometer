#!/bin/bash

BASE_PATH=${MAGNETOMETER_BASE_PATH:-/home/pi/UKRAA_Magnetometer}
LOG_DIR="$BASE_PATH/logfiles"
MAIN_LOG="$LOG_DIR/log-MagnetometerACM0.txt"
ERROR_LOG="$LOG_DIR/log-error.txt"
CONFIG_PATH=${MAGNETOMETER_REMOTE_UPLOAD_CONFIG:-$BASE_PATH/config/remote-upload.ini}
MODE=$1

log_msg() {
    printf '%s : %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1"
}

if [ -z "$MODE" ]; then
    log_msg "uploadRemoteACM0.sh       : FAILED - mode is required (daily|rolling)" >> "$ERROR_LOG"
    exit 2
fi

if [ "$MODE" != "daily" ] && [ "$MODE" != "rolling" ]; then
    log_msg "uploadRemoteACM0.sh       : FAILED - invalid mode '$MODE' (use daily|rolling)" >> "$ERROR_LOG"
    exit 2
fi

if [ ! -f "$CONFIG_PATH" ]; then
    log_msg "uploadRemoteACM0.sh       : FAILED - missing config file: $CONFIG_PATH" >> "$ERROR_LOG"
    exit 1
fi

log_msg "uploadRemoteACM0.sh       : Started remote FTP upload ($MODE)" >> "$MAIN_LOG"

UPLOAD_OUTPUT=$(mktemp)
/usr/bin/python3 - "$MODE" "$BASE_PATH" "$CONFIG_PATH" > "$UPLOAD_OUTPUT" 2>&1 <<'PY'
import configparser
import ftplib
import os
import posixpath
import sys


def parse_bool(value, default_value):
    if value is None:
        return default_value
    return value.strip().lower() in ('1', 'true', 'yes', 'y', 'on')


def cfg_value(parser, section, option, default_value=''):
    if parser.has_section(section) and parser.has_option(section, option):
        return parser.get(section, option).strip()
    return default_value


def redact_sensitive(text, user, password):
    redacted = str(text)
    if user:
        redacted = redacted.replace(user, '[redacted-user]')
    if password:
        redacted = redacted.replace(password, '[redacted-password]')
    return redacted


def ensure_remote_dir(ftp, remote_dir):
    if remote_dir in ('', '.', '/'): 
        if remote_dir == '/':
            ftp.cwd('/')
        return

    if remote_dir.startswith('/'):
        ftp.cwd('/')
        parts = [p for p in remote_dir.split('/') if p]
    else:
        parts = [p for p in remote_dir.split('/') if p]

    for part in parts:
        try:
            ftp.cwd(part)
        except ftplib.error_perm:
            ftp.mkd(part)
            ftp.cwd(part)


def upload_files(mode, base_path, config_path):
    parser = configparser.ConfigParser()
    with open(config_path, mode='r', encoding='utf-8-sig') as config_file:
        parser.read_string(config_file.read())

    enabled = parse_bool(cfg_value(parser, 'ftp', 'enabled', 'false'), False)
    if not enabled:
        print('INFO: Remote FTP upload disabled (ftp.enabled=false)')
        return 0

    site = cfg_value(parser, 'ftp', 'site', '')
    user = cfg_value(parser, 'ftp', 'user', '')
    password = cfg_value(parser, 'ftp', 'password', '')
    base_remote_dir = cfg_value(parser, 'ftp', 'directory', '/data')

    port_text = cfg_value(parser, 'ftp', 'port', '21')
    timeout_text = cfg_value(parser, 'ftp', 'timeout_seconds', '30')
    passive = parse_bool(cfg_value(parser, 'ftp', 'passive', 'true'), True)
    create_dirs = parse_bool(cfg_value(parser, 'ftp', 'create_dirs', 'true'), True)
    upload_status_json = parse_bool(cfg_value(parser, 'ftp', 'upload_status_json', 'false'), False)

    try:
        port = int(port_text)
    except ValueError:
        print('ERROR: Invalid ftp.port value in config')
        return 1

    try:
        timeout_seconds = int(timeout_text)
    except ValueError:
        print('ERROR: Invalid ftp.timeout_seconds value in config')
        return 1

    if not (site and user and password and base_remote_dir):
        print('ERROR: FTP config incomplete (need site, user, password, directory)')
        return 1

    base_remote_dir = base_remote_dir.rstrip('/') or '/'

    if mode == 'daily':
        upload_entries = [
            ('Activity.png', os.path.join(base_path, 'temp', 'Activity.png'), base_remote_dir),
            ('XYZ.png', os.path.join(base_path, 'temp', 'XYZ.png'), base_remote_dir),
        ]

        optional_daily_entries = [
            ('HDZ.png', os.path.join(base_path, 'temp', 'HDZ.png'), base_remote_dir),
            ('BI.png', os.path.join(base_path, 'temp', 'BI.png'), base_remote_dir),
        ]

        for file_name, local_path, remote_dir in optional_daily_entries:
            if os.path.exists(local_path):
                upload_entries.append((file_name, local_path, remote_dir))
            else:
                print(f'INFO: Optional daily file not present, skipping: {file_name}')
    else:
        rolling_remote_dir = posixpath.join(base_remote_dir, 'rolling')
        upload_entries = [
            ('RollingActivity.png', os.path.join(base_path, 'temp', 'rolling', 'RollingActivity.png'), rolling_remote_dir),
            ('RollingXYZ.png', os.path.join(base_path, 'temp', 'rolling', 'RollingXYZ.png'), rolling_remote_dir),
        ]

        if upload_status_json:
            status_remote_dir = posixpath.join(base_remote_dir, 'status')
            upload_entries.append(
                ('current.json', os.path.join(base_path, 'data', 'status', 'current.json'), status_remote_dir))

    missing = [name for name, local_path, _ in upload_entries if not os.path.exists(local_path)]
    if missing:
        print('ERROR: Missing local file(s): ' + ', '.join(missing))
        return 1

    try:
        with ftplib.FTP() as ftp:
            ftp.connect(site, port, timeout=timeout_seconds)
            ftp.login(user=user, passwd=password)
            ftp.set_pasv(passive)
            print(f'INFO: Connected to FTP host {site}:{port} as [redacted-user]')

            for file_name, local_path, remote_dir in upload_entries:
                if create_dirs:
                    ensure_remote_dir(ftp, remote_dir)
                else:
                    ftp.cwd(remote_dir)

                with open(local_path, mode='rb') as image_file:
                    ftp.storbinary(f'STOR {file_name}', image_file)
                print(f'INFO: Uploaded {file_name} to {remote_dir}')
    except Exception as exc:
        print('ERROR: FTP upload failed: ' + redact_sensitive(str(exc), user, password))
        return 1

    return 0


def main():
    if len(sys.argv) != 4:
        print('ERROR: Internal argument error')
        return 2

    mode = sys.argv[1]
    base_path = sys.argv[2]
    config_path = sys.argv[3]
    return upload_files(mode, base_path, config_path)


if __name__ == '__main__':
    raise SystemExit(main())
PY
UPLOAD_EXIT=$?

while IFS= read -r line; do
    if [ -z "$line" ]; then
        continue
    fi

    case "$line" in
        INFO:*)
            log_msg "uploadRemoteACM0.sh       : ${line#INFO: }" >> "$MAIN_LOG"
            ;;
        ERROR:*)
            log_msg "uploadRemoteACM0.sh       : FAILED - ${line#ERROR: }" >> "$ERROR_LOG"
            ;;
        *)
            log_msg "uploadRemoteACM0.sh       : $line" >> "$MAIN_LOG"
            ;;
    esac
done < "$UPLOAD_OUTPUT"

rm -f "$UPLOAD_OUTPUT"

if [ "$UPLOAD_EXIT" -eq 0 ]; then
    log_msg "uploadRemoteACM0.sh       : Completed remote FTP upload ($MODE)" >> "$MAIN_LOG"
    exit 0
fi

log_msg "uploadRemoteACM0.sh       : FAILED remote FTP upload ($MODE)" >> "$ERROR_LOG"
exit "$UPLOAD_EXIT"
