#!/usr/bin/env python3

import csv
import json
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

    if grp is None or pwd is None or not hasattr(os, 'geteuid') or os.geteuid() != 0:
        return

    owner_name = os.environ.get('MAGNETOMETER_FILE_OWNER', 'pi')
    try:
        owner = pwd.getpwnam(owner_name)
        group = grp.getgrnam(owner_name)
    except KeyError:
        print(f'INFO: File owner {owner_name} not found, leaving current ownership')
        return

    os.chown(output_path, owner.pw_uid, group.gr_gid)


def normalise_time(value):
    return value.replace('T', ' ').removesuffix('Z')


def download_forecast(url, output_path):
    output_dir = os.path.dirname(output_path)
    os.makedirs(output_dir, exist_ok=True)

    file_descriptor, temporary_path = tempfile.mkstemp(
        prefix='.latest-', suffix='.csv.tmp', dir=output_dir)
    os.close(file_descriptor)

    try:
        request = urllib.request.Request(url, headers={'User-Agent': 'UKRAA-Magnetometer/1.0'})
        with urllib.request.urlopen(request, timeout=30) as response:
            payload = json.load(response)

        rows = []
        for record in payload:
            try:
                timestamp = normalise_time(record['time_tag'])
                kp_value = float(record['kp'])
            except (KeyError, TypeError, ValueError):
                continue

            if not 0 <= kp_value <= 9:
                continue

            rows.append((timestamp, f'{kp_value:.2f}'))

        if not rows:
            print('ERROR: NOAA Kp forecast contained no valid records')
            return 1

        with open(temporary_path, mode='w', encoding='utf-8', newline='') as output_file:
            writer = csv.writer(output_file)
            writer.writerows(rows)

        os.replace(temporary_path, output_path)
        set_output_permissions(output_path)
        print(f'INFO: Downloaded NOAA planetary Kp forecast ({len(rows)} records)')
        return 0
    except (OSError, urllib.error.URLError, json.JSONDecodeError) as exc:
        print('ERROR: NOAA Kp forecast download failed: ' + str(exc))
        return 1
    finally:
        if os.path.exists(temporary_path):
            os.remove(temporary_path)


def main():
    if len(sys.argv) != 3:
        print('ERROR: Internal argument error')
        return 2

    return download_forecast(sys.argv[1], sys.argv[2])


if __name__ == '__main__':
    raise SystemExit(main())