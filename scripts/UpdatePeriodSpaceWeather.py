#!/usr/bin/env python3

import argparse
import datetime
import sys

from magnetometer_common import get_base_path
from magnetometer_common import get_period_plot_options
from magnetometer_common import get_target_date
from space_weather import REFRESH_DAYS
from space_weather import fetch_range
from space_weather import update_cache


PERIOD_DAY_COUNTS = {
    'week': 7,
    'month': 30,
    '3month': 90,
    '6month': 183,
    'year': 365,
}
CME_LEAD_DAYS = 7


def required_start_date(end_date, period_options):
    enabled_days = [PERIOD_DAY_COUNTS[name] for name, enabled in period_options.items()
                    if enabled and name in PERIOD_DAY_COUNTS]
    longest_period = max(enabled_days, default=PERIOD_DAY_COUNTS['week'])
    return end_date - datetime.timedelta(days=longest_period + CME_LEAD_DAYS - 1)


def parse_arguments():
    parser = argparse.ArgumentParser(
        description='Refresh historical Kp and storm data for period plot overlays.')
    parser.add_argument('--end-date', type=datetime.date.fromisoformat)
    parser.add_argument('--delay', type=float, default=2.0)
    return parser.parse_args()


def main():
    arguments = parse_arguments()
    if arguments.delay < 0:
        sys.exit('--delay must be zero or greater')
    base_path = get_base_path()
    end_date = arguments.end_date or get_target_date()
    start_date = required_start_date(end_date, get_period_plot_options(base_path))

    try:
        update_cache(
            base_path, start_date, end_date,
            refresh_days=REFRESH_DAYS,
            range_fetcher=lambda start, end: fetch_range(start, end, delay=arguments.delay))
    except (OSError, TypeError, ValueError, TimeoutError) as error:
        print('WARNING: space-weather refresh failed: {}'.format(error), file=sys.stderr)
        return 1

    return 0


if __name__ == '__main__':
    raise SystemExit(main())