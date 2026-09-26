#!/usr/bin/env python3

import argparse
import csv
import datetime
import json
import os

from magnetometer_common import get_base_path
from magnetometer_common import get_period_plot_options
from magnetometer_common import get_plot_options
from magnetometer_common import get_target_date


PERIOD_DAY_COUNTS = {
    'week': 7,
    'month': 30,
    '3month': 90,
    '6month': 183,
    'year': 365,
}
MINIMUM_DAILY_COVERAGE_PERCENT = 95.0


def parse_arguments():
    parser = argparse.ArgumentParser(
        description='Report data availability for long-period magnetic plots.')
    parser.add_argument('--end-date', type=datetime.date.fromisoformat)
    parser.add_argument('--write-status', action='store_true')
    return parser.parse_args()


def load_complete_dates(base_path):
    summary_path = os.path.join(base_path, 'data', 'daily', 'summary.csv')
    complete_dates = set()

    if not os.path.exists(summary_path):
        return complete_dates

    with open(summary_path, mode='r', encoding='UTF-8', newline='') as summary_file:
        for row in csv.DictReader(summary_file):
            try:
                summary_date = datetime.datetime.strptime(
                    row['DateTime'], '%Y-%m-%d %H:%M:%S').date()
                coverage_percent = float(row['CoveragePercent'])
            except (KeyError, TypeError, ValueError):
                continue

            if coverage_percent >= MINIMUM_DAILY_COVERAGE_PERCENT:
                complete_dates.add(summary_date)

    return complete_dates


def build_period_status(end_date, complete_dates, period_options):
    periods = {}
    for period_name, required_days in PERIOD_DAY_COUNTS.items():
        start_date = end_date - datetime.timedelta(days=required_days - 1)
        expected_dates = {
            start_date + datetime.timedelta(days=day_offset)
            for day_offset in range(required_days)
        }
        valid_days = len(expected_dates.intersection(complete_dates))
        enabled = period_options[period_name]
        periods[period_name] = {
            'enabled': enabled,
            'available': enabled and valid_days == required_days,
            'required_days': required_days,
            'valid_days': valid_days,
            'start_date': start_date.isoformat(),
            'end_date': end_date.isoformat(),
        }

    return periods


def build_status(base_path, end_date):
    plot_hdz, plot_bi, _, _ = get_plot_options(base_path)
    period_options = get_period_plot_options(base_path)
    complete_dates = load_complete_dates(base_path)

    return {
        'generated_at_utc': datetime.datetime.now(
            datetime.timezone.utc).replace(microsecond=0).isoformat(),
        'minimum_daily_coverage_percent': MINIMUM_DAILY_COVERAGE_PERCENT,
        'families': {
            'xyz': True,
            'hdz': plot_hdz,
            'bi': plot_bi,
        },
        'periods': build_period_status(end_date, complete_dates, period_options),
    }


def write_status(base_path, status):
    status_directory = os.path.join(base_path, 'data', 'status')
    os.makedirs(status_directory, exist_ok=True)
    status_path = os.path.join(status_directory, 'period-plots.json')
    temporary_path = status_path + '.tmp'
    with open(temporary_path, mode='w', encoding='UTF-8') as status_file:
        json.dump(status, status_file, indent=2, sort_keys=True)
        status_file.write('\n')
    os.replace(temporary_path, status_path)


def main():
    arguments = parse_arguments()
    end_date = arguments.end_date or get_target_date()
    base_path = get_base_path()
    status = build_status(base_path, end_date)

    if arguments.write_status:
        write_status(base_path, status)

    print(json.dumps(status, sort_keys=True))


if __name__ == '__main__':
    main()