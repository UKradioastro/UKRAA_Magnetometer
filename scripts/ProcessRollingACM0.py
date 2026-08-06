#!/usr/bin/env python3

import csv
import datetime
import json
import math
import os
import statistics

from magnetometer_common import RAW_FIELD_NAMES
from magnetometer_common import build_day_path
from magnetometer_common import calculate_hdzbi
from magnetometer_common import ensure_directory
from magnetometer_common import format_fixed
from magnetometer_common import get_base_path
from magnetometer_common import parse_raw_datetime
from magnetometer_common import utc_now


def log_msg(message):
    print(datetime.datetime.strftime(datetime.datetime.now(), '%Y-%m-%d %H:%M:%S'),
        ':',
        'ProcessRollingACM0.py   :',
        message)


def get_window_end_exclusive():
    rolling_end = os.environ.get('MAGNETOMETER_ROLLING_END')
    if rolling_end:
        normalized = rolling_end.replace('T', ' ')
        return datetime.datetime.strptime(normalized, '%Y-%m-%d %H:%M:%S')

    current_time = utc_now().replace(tzinfo=None)
    return current_time.replace(second=0, microsecond=0)


def get_alert_threshold(name, default_value):
    return float(os.environ.get(name, default_value))


def get_stale_seconds():
    return int(os.environ.get('MAGNETOMETER_STALE_SECONDS', '600'))


def build_rolling_csv_path(base_path):
    return os.path.join(base_path, 'data', 'rolling', 'latest-24h.csv')


def build_status_json_path(base_path):
    return os.path.join(base_path, 'data', 'status', 'current.json')


def create_empty_minute_bins(total_minutes):
    return [
        {
            'x_v': [],
            'x_nt': [],
            'y_v': [],
            'y_nt': [],
            'z_v': [],
            'z_nt': [],
            'tmp36_degc': [],
            'delta_nt': [],
        }
        for _ in range(total_minutes)
    ]


def median_or_nan(values):
    if values:
        return statistics.median(values)

    return math.nan


def determine_alert_level(latest_activity_nt, watch_threshold, active_threshold):
    if math.isnan(latest_activity_nt):
        return 'unknown'

    if latest_activity_nt >= active_threshold:
        return 'active'

    if latest_activity_nt >= watch_threshold:
        return 'watch'

    return 'quiet'


def minute_range_days(window_start, window_end_exclusive):
    current_date = window_start.date()
    end_date = (window_end_exclusive - datetime.timedelta(seconds=1)).date()

    while current_date <= end_date:
        yield current_date
        current_date = current_date + datetime.timedelta(days=1)


def load_window_bins(base_path, window_start, window_end_exclusive):
    minute_bins = create_empty_minute_bins(1440)
    detector_name = ''
    latest_sample_time = None
    samples_seen = 0

    for target_date in minute_range_days(window_start, window_end_exclusive):
        raw_data_file = build_day_path(base_path, 'raw', target_date)
        if not os.path.exists(raw_data_file):
            continue

        with open(file=raw_data_file, mode='r', encoding='UTF-8') as raw_file:
            raw_csv_reader = csv.DictReader(raw_file, RAW_FIELD_NAMES)

            for raw_line in raw_csv_reader:
                raw_datetime = parse_raw_datetime(raw_line['RawDateTime'])
                if raw_datetime < window_start or raw_datetime >= window_end_exclusive:
                    continue

                minute_index = int((raw_datetime - window_start).total_seconds() // 60)
                minute_bin = minute_bins[minute_index]

                minute_bin['x_v'].append(float(raw_line['RawX_V']))
                minute_bin['x_nt'].append(float(raw_line['RawX_nT']))
                minute_bin['y_v'].append(float(raw_line['RawY_V']))
                minute_bin['y_nt'].append(float(raw_line['RawY_nT']))
                minute_bin['z_v'].append(float(raw_line['RawZ_V']))
                minute_bin['z_nt'].append(float(raw_line['RawZ_nT']))
                minute_bin['tmp36_degc'].append(float(raw_line['RawTMP36_degC']))
                minute_bin['delta_nt'].append(float(raw_line['RawDelta_nT']))

                detector_name = str(raw_line['RawDetectorName'])
                latest_sample_time = raw_datetime
                samples_seen += 1

    return minute_bins, detector_name, latest_sample_time, samples_seen


def write_rolling_csv(output_path, window_start, minute_bins, detector_name):
    ensure_directory(os.path.dirname(output_path))

    with open(file=output_path, mode='w', encoding='UTF-8') as output_file:
        processed_time = window_start - datetime.timedelta(minutes=1)

        for minute_bin in minute_bins:
            processed_time = processed_time + datetime.timedelta(minutes=1)

            median_x_v = median_or_nan(minute_bin['x_v'])
            median_x_nt = median_or_nan(minute_bin['x_nt'])
            median_y_v = median_or_nan(minute_bin['y_v'])
            median_y_nt = median_or_nan(minute_bin['y_nt'])
            median_z_v = median_or_nan(minute_bin['z_v'])
            median_z_nt = median_or_nan(minute_bin['z_nt'])
            median_tmp36_degc = median_or_nan(minute_bin['tmp36_degc'])
            median_delta_nt = median_or_nan(minute_bin['delta_nt'])

            calc_h, calc_d, calc_z, calc_b, calc_i = calculate_hdzbi(
                median_x_nt,
                median_y_nt,
                median_z_nt)

            output_file.write(str(processed_time))
            output_file.write(',')
            output_file.write(format_fixed(median_x_v, 6))
            output_file.write(',')
            output_file.write(format_fixed(median_y_v, 6))
            output_file.write(',')
            output_file.write(format_fixed(median_z_v, 6))
            output_file.write(',')
            output_file.write(format_fixed(median_x_nt, 0))
            output_file.write(',')
            output_file.write(format_fixed(median_y_nt, 0))
            output_file.write(',')
            output_file.write(format_fixed(median_z_nt, 0))
            output_file.write(',')
            output_file.write(format_fixed(median_tmp36_degc, 1))
            output_file.write(',')
            output_file.write(format_fixed(median_delta_nt, 1))
            output_file.write(',')
            output_file.write(format_fixed(calc_h, 0))
            output_file.write(',')
            output_file.write(format_fixed(calc_d, 1))
            output_file.write(',')
            output_file.write(format_fixed(calc_z, 0))
            output_file.write(',')
            output_file.write(format_fixed(calc_b, 0))
            output_file.write(',')
            output_file.write(format_fixed(calc_i, 1))
            output_file.write(',')
            output_file.write(detector_name)
            output_file.write('\n')


def write_status_json(
    output_path,
    csv_path,
    window_start,
    window_end_exclusive,
    latest_sample_time,
    latest_activity_nt,
    detector_name,
    samples_seen):
    ensure_directory(os.path.dirname(output_path))

    watch_threshold = get_alert_threshold('MAGNETOMETER_ALERT_WATCH_NT', '5')
    active_threshold = get_alert_threshold('MAGNETOMETER_ALERT_ACTIVE_NT', '15')
    stale_seconds = get_stale_seconds()

    latest_processed_minute = window_end_exclusive - datetime.timedelta(minutes=1)
    latest_sample_age_seconds = None
    is_stale = True

    if latest_sample_time is not None:
        latest_sample_age_seconds = int((window_end_exclusive - latest_sample_time).total_seconds())
        is_stale = latest_sample_age_seconds > stale_seconds

    status = {
        'generated_at_utc': utc_now().replace(microsecond=0).isoformat(),
        'window_start_utc': window_start.isoformat(sep=' '),
        'window_end_exclusive_utc': window_end_exclusive.isoformat(sep=' '),
        'latest_processed_minute_utc': latest_processed_minute.isoformat(sep=' '),
        'latest_sample_time_utc': latest_sample_time.isoformat(sep=' ') if latest_sample_time else None,
        'latest_sample_age_seconds': latest_sample_age_seconds,
        'is_stale': is_stale,
        'latest_activity_nt': None if math.isnan(latest_activity_nt) else float(format_fixed(latest_activity_nt, 1)),
        'alert_level': determine_alert_level(latest_activity_nt, watch_threshold, active_threshold),
        'watch_threshold_nt': watch_threshold,
        'active_threshold_nt': active_threshold,
        'stale_threshold_seconds': stale_seconds,
        'detector_name': detector_name,
        'samples_seen': samples_seen,
        'rolling_csv_path': csv_path,
    }

    with open(file=output_path, mode='w', encoding='UTF-8') as output_file:
        json.dump(status, output_file, indent=2)
        output_file.write('\n')


def main():
    base_path = get_base_path()
    window_end_exclusive = get_window_end_exclusive()
    window_start = window_end_exclusive - datetime.timedelta(hours=24)

    log_msg('Started processing rolling magnetometer data from '
            + window_start.strftime('%Y-%m-%d %H:%M:%S')
            + ' to '
            + window_end_exclusive.strftime('%Y-%m-%d %H:%M:%S'))

    rolling_csv_path = build_rolling_csv_path(base_path)
    status_json_path = build_status_json_path(base_path)

    minute_bins, detector_name, latest_sample_time, samples_seen = load_window_bins(
        base_path,
        window_start,
        window_end_exclusive)

    write_rolling_csv(rolling_csv_path, window_start, minute_bins, detector_name)

    latest_activity_nt = median_or_nan(minute_bins[-1]['delta_nt'])
    write_status_json(
        status_json_path,
        rolling_csv_path,
        window_start,
        window_end_exclusive,
        latest_sample_time,
        latest_activity_nt,
        detector_name,
        samples_seen)

    log_msg('Completed processing rolling magnetometer data to ' + rolling_csv_path)


if __name__ == '__main__':
    main()