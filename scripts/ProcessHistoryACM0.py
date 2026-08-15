#!/usr/bin/env python3

import argparse
import csv
import datetime
import os

from magnetometer_common import ensure_directory
from magnetometer_common import get_base_path
from magnetometer_common import get_target_date
from magnetometer_common import parse_raw_datetime

# supported history windows and their span in days
WINDOWS = {
    '7d': 7,
    '1m': 30,
    '3m': 90,
    '6m': 180,
    '1y': 365,
}


def log_msg(message):
    print(datetime.datetime.strftime(datetime.datetime.now(), '%Y-%m-%d %H:%M:%S'),
        ':',
        'ProcessHistoryACM0.py   :',
        message)


def build_hourly_day_path(base_path, target_date):
    return os.path.join(
        base_path,
        'data',
        'processed',
        'hour',
        target_date.strftime('%Y'),
        target_date.strftime('%Y-%m'),
        target_date.strftime('%Y-%m-%d') + '.csv')


def build_history_dir(base_path, window_key):
    return os.path.join(base_path, 'data', 'history', window_key)


def read_day_rows(hourly_file_path):
    rows = []

    if not os.path.exists(hourly_file_path):
        return rows

    with open(file=hourly_file_path, mode='r', encoding='UTF-8') as hourly_file:
        for row in csv.reader(hourly_file):
            if row:
                rows.append(row)

    return rows


def collect_window_rows(base_path, end_date, span_days):
    all_rows = []

    for day_offset in range(span_days - 1, -1, -1):
        day = end_date - datetime.timedelta(days=day_offset)
        hourly_file_path = build_hourly_day_path(base_path, day)
        all_rows.extend(read_day_rows(hourly_file_path))

    # hourly files are read oldest-first already, but sort defensively by timestamp
    all_rows.sort(key=lambda row: parse_raw_datetime(row[0]))

    return all_rows


def write_history_csv(base_path, window_key, rows):
    history_dir = build_history_dir(base_path, window_key)
    ensure_directory(history_dir)

    history_file_path = os.path.join(history_dir, 'history.csv')

    with open(file=history_file_path, mode='w', encoding='UTF-8') as history_file:
        writer = csv.writer(history_file)
        writer.writerows(rows)

    return history_file_path


def parse_args():
    parser = argparse.ArgumentParser(description='Assemble historical magnetometer CSV windows.')
    parser.add_argument(
        '--window',
        choices=sorted(WINDOWS.keys()),
        help='Single window to build; if omitted, all windows are built.')
    return parser.parse_args()


def main():
    args = parse_args()
    base_path = get_base_path()
    end_date = get_target_date()

    windows_to_build = [args.window] if args.window else sorted(WINDOWS.keys())

    for window_key in windows_to_build:
        span_days = WINDOWS[window_key]
        rows = collect_window_rows(base_path, end_date, span_days)
        history_file_path = write_history_csv(base_path, window_key, rows)
        log_msg(f'Wrote {len(rows)} row(s) for window {window_key} to {history_file_path}')


if __name__ == '__main__':
    log_msg('Started building historical data windows')
    main()
    log_msg('Completed building historical data windows')
