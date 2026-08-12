#!/usr/bin/env python3

import argparse
import csv
import datetime
import os
import sys

from magnetometer_common import get_base_path
from magnetometer_common import get_target_date

WINDOWS = {
    '7d': 7,
    '1m': 30,
    '3m': 90,
    '6m': 180,
    '1y': 365,
}


def log_msg(message):
    print(datetime.datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S'), ':', 'ProcessHistoryACM0.py :', message)


def iter_hourly_csv_files(base_path):
    base_root = os.path.join(base_path, 'data', 'processed', 'hour')
    if not os.path.isdir(base_root):
        return []

    files = []
    for year_dir in sorted(os.listdir(base_root)):
        year_path = os.path.join(base_root, year_dir)
        if not os.path.isdir(year_path):
            continue
        for month_dir in sorted(os.listdir(year_path)):
            month_path = os.path.join(year_path, month_dir)
            if not os.path.isdir(month_path):
                continue
            for file_name in sorted(os.listdir(month_path)):
                if file_name.endswith('.csv'):
                    files.append(os.path.join(month_path, file_name))
    return files


def parse_dt(value):
    return datetime.datetime.strptime(value.strip(), '%Y-%m-%d %H:%M:%S')


def window_start_and_end(target_date, window_key):
    end_dt = datetime.datetime.combine(target_date, datetime.time(23, 59, 59))
    span_days = WINDOWS[window_key]
    start_dt = end_dt - datetime.timedelta(days=span_days - 1, hours=23, minutes=59, seconds=59)
    return start_dt, end_dt


def ensure_output_dir(base_path, window_key):
    output_dir = os.path.join(base_path, 'data', 'history', window_key)
    os.makedirs(output_dir, exist_ok=True)
    return output_dir


def read_hourly_rows(base_path, start_dt, end_dt):
    rows = []
    for file_path in iter_hourly_csv_files(base_path):
        try:
            with open(file_path, mode='r', encoding='UTF-8', newline='') as csv_file:
                reader = csv.reader(csv_file)
                for row in reader:
                    if not row or len(row) < 15:
                        continue
                    dt_value = row[0].strip()
                    try:
                        row_dt = parse_dt(dt_value)
                    except ValueError:
                        continue
                    if start_dt <= row_dt <= end_dt:
                        rows.append(row)
        except FileNotFoundError:
            continue
    rows.sort(key=lambda row: parse_dt(row[0]))
    return rows


def write_window_csv(base_path, window_key, target_date):
    output_dir = ensure_output_dir(base_path, window_key)
    output_path = os.path.join(output_dir, 'history.csv')
    start_dt, end_dt = window_start_and_end(target_date, window_key)
    rows = read_hourly_rows(base_path, start_dt, end_dt)

    with open(output_path, mode='w', encoding='UTF-8', newline='') as output_file:
        writer = csv.writer(output_file)
        for row in rows:
            writer.writerow(row)

    log_msg(f'Wrote {len(rows)} rows for window {window_key} to {output_path}')
    return output_path


def parse_args():
    parser = argparse.ArgumentParser(description='Build historical hourly magnetometer CSV windows.')
    parser.add_argument('--window', choices=sorted(WINDOWS.keys()), help='Specific window to generate.')
    return parser.parse_args()


def main():
    args = parse_args()
    base_path = get_base_path()
    target_date = get_target_date()

    windows = [args.window] if args.window else sorted(WINDOWS.keys())
    produced = 0

    for window_key in windows:
        output_path = write_window_csv(base_path, window_key, target_date)
        if os.path.getsize(output_path) > 0:
            produced += 1

    if produced == 0:
        raise SystemExit('No history CSV rows were produced for the selected window(s).')

    log_msg(f'Completed history generation for {len(windows)} window(s). Base path: {base_path}')


if __name__ == '__main__':
    try:
        main()
    except Exception as exc:  # pragma: no cover - CLI safety
        log_msg(f'FAILED: {exc}')
        raise SystemExit(1)
