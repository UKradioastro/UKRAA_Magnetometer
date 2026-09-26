#!/usr/bin/env python3

import argparse
import csv
import datetime
import math
import os
import statistics

from magnetometer_common import build_day_path
from magnetometer_common import build_month_path
from magnetometer_common import calculate_hdzbi
from magnetometer_common import ensure_directory
from magnetometer_common import format_fixed
from magnetometer_common import get_base_path
from magnetometer_common import get_target_date
from magnetometer_common import log_message


SUMMARY_FIELD_COUNT = 12
MINUTE_COUNT_PER_DAY = 1440
SUMMARY_HEADER = [
    'DateTime',
    'X_nT',
    'Y_nT',
    'Z_nT',
    'TMP36_degC',
    'DeltaMax_nT',
    'H_nT',
    'D_deg',
    'B_nT',
    'I_deg',
    'ValidMinutes',
    'CoveragePercent',
]


def log_msg(message):
    log_message('ProcessDailySummary.py', message)


def numeric_value(row, index):
    try:
        value = float(row[index])
    except (IndexError, TypeError, ValueError):
        return math.nan

    return value if math.isfinite(value) else math.nan


def mean_or_nan(values):
    return statistics.fmean(values) if values else math.nan


def build_daily_summary(target_date, minute_path):
    x_values = []
    y_values = []
    z_values = []
    temperature_values = []
    delta_values = []
    valid_minutes = 0

    with open(minute_path, mode='r', encoding='UTF-8', newline='') as minute_file:
        for row in csv.reader(minute_file):
            x_value = numeric_value(row, 4)
            y_value = numeric_value(row, 5)
            z_value = numeric_value(row, 6)

            if math.isnan(x_value) or math.isnan(y_value) or math.isnan(z_value):
                continue

            x_values.append(x_value)
            y_values.append(y_value)
            z_values.append(z_value)
            valid_minutes += 1

            temperature_value = numeric_value(row, 7)
            if not math.isnan(temperature_value):
                temperature_values.append(temperature_value)

            delta_value = numeric_value(row, 8)
            if not math.isnan(delta_value):
                delta_values.append(delta_value)

    average_x = mean_or_nan(x_values)
    average_y = mean_or_nan(y_values)
    average_z = mean_or_nan(z_values)
    average_temperature = mean_or_nan(temperature_values)
    maximum_delta = max(delta_values) if delta_values else math.nan
    horizontal, declination, _, total_field, inclination = calculate_hdzbi(
        average_x,
        average_y,
        average_z)
    coverage_percent = (valid_minutes / MINUTE_COUNT_PER_DAY) * 100

    return [
        target_date.strftime('%Y-%m-%d 12:00:00'),
        format_fixed(average_x, 1),
        format_fixed(average_y, 1),
        format_fixed(average_z, 1),
        format_fixed(average_temperature, 1),
        format_fixed(maximum_delta, 1),
        format_fixed(horizontal, 1),
        format_fixed(declination, 2),
        format_fixed(total_field, 1),
        format_fixed(inclination, 2),
        str(valid_minutes),
        format_fixed(coverage_percent, 1),
    ]


def write_daily_summary(base_path, target_date):
    minute_path = build_day_path(base_path, 'minute', target_date)
    if not os.path.exists(minute_path):
        raise FileNotFoundError('minute data file missing: ' + minute_path)

    summary_path = build_day_path(base_path, 'daily', target_date)
    summary_month_path = build_month_path(base_path, 'daily', target_date)
    if not os.path.exists(summary_month_path):
        ensure_directory(summary_month_path)
        log_msg('New directory created : ' + summary_month_path)

    summary_row = build_daily_summary(target_date, minute_path)
    temporary_path = summary_path + '.tmp'
    with open(temporary_path, mode='w', encoding='UTF-8', newline='') as summary_file:
        csv.writer(summary_file).writerow(summary_row)
    os.replace(temporary_path, summary_path)
    log_msg('Created daily summary for ' + target_date.strftime('%Y-%m-%d')
            + ' with ' + summary_row[10] + ' valid minutes')


def list_minute_dates(base_path):
    minute_root = os.path.join(base_path, 'data', 'minute')
    dates = []
    if not os.path.isdir(minute_root):
        return dates

    for year_name in sorted(os.listdir(minute_root)):
        year_path = os.path.join(minute_root, year_name)
        if not os.path.isdir(year_path):
            continue
        for month_name in sorted(os.listdir(year_path)):
            month_path = os.path.join(year_path, month_name)
            if not os.path.isdir(month_path):
                continue
            for file_name in sorted(os.listdir(month_path)):
                if not file_name.endswith('.csv'):
                    continue
                try:
                    dates.append(datetime.datetime.strptime(file_name[:-4], '%Y-%m-%d').date())
                except ValueError:
                    continue

    return dates


def rebuild_combined_summary(base_path):
    daily_root = os.path.join(base_path, 'data', 'daily')
    summary_path = os.path.join(daily_root, 'summary.csv')
    summary_rows = []

    for root_path, _, file_names in os.walk(daily_root):
        for file_name in file_names:
            if file_name == 'summary.csv' or not file_name.endswith('.csv'):
                continue
            file_path = os.path.join(root_path, file_name)
            with open(file_path, mode='r', encoding='UTF-8', newline='') as daily_file:
                for row in csv.reader(daily_file):
                    if len(row) == SUMMARY_FIELD_COUNT:
                        summary_rows.append(row)

    summary_rows.sort(key=lambda row: row[0])
    ensure_directory(daily_root)
    temporary_path = summary_path + '.tmp'
    with open(temporary_path, mode='w', encoding='UTF-8', newline='') as summary_file:
        csv.writer(summary_file).writerow(SUMMARY_HEADER)
        csv.writer(summary_file).writerows(summary_rows)
    os.replace(temporary_path, summary_path)
    log_msg('Rebuilt combined daily summary with ' + str(len(summary_rows)) + ' days')


def parse_arguments():
    parser = argparse.ArgumentParser(
        description='Generate daily magnetic summaries for period plots.')
    parser.add_argument(
        '--all',
        action='store_true',
        help='Generate summaries for every available minute-data day.')
    return parser.parse_args()


def main():
    arguments = parse_arguments()
    base_path = get_base_path()
    target_dates = list_minute_dates(base_path) if arguments.all else [get_target_date()]

    if not target_dates:
        log_msg('No minute data found for daily summary generation')
        return 0

    for target_date in target_dates:
        write_daily_summary(base_path, target_date)

    rebuild_combined_summary(base_path)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())