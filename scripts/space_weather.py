#!/usr/bin/env python3

import csv
import datetime
import io
import json
import os
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request

from magnetometer_common import log_message


GFZ_URL = 'https://kp.gfz.de/app/json/'
DONKI_URL = 'https://ccmc.gsfc.nasa.gov/DONKI-API/get/'
USER_AGENT = 'UKRAA-PicoMagnetometer/1.0'
TIME_FORMAT = '%Y-%m-%d %H:%M:%S'
REFRESH_DAYS = 45
DONKI_MAX_RANGE_DAYS = 60
# GFZ publishes definitive Kp roughly a month in arrears; newer values are
# preliminary ('pre') or nowcast ('now') and are refetched until definitive.
KP_STATUS_DEFINITIVE = 'def'
KP_STATUS_PRELIMINARY = 'pre'


def parse_time(text):
    for time_format in ('%Y-%m-%dT%H:%MZ', '%Y-%m-%dT%H:%M:%SZ',
                        '%Y-%m-%dT%H:%M:%S', TIME_FORMAT):
        try:
            return datetime.datetime.strptime(text, time_format)
        except (TypeError, ValueError):
            continue
    return None


def activity_time(activity_id):
    return parse_time(activity_id[:19])


def storm_level(kp_value):
    return max(0, min(5, int(kp_value + 1.0 / 3.0 + 1e-6) - 4))


def fetch_json(url, delay=2.0, opener=None, sleep=None):
    opener = opener or urllib.request.urlopen
    sleep = sleep or time.sleep
    request = urllib.request.Request(url, headers={'User-Agent': USER_AGENT})

    for attempt in range(3):
        try:
            with opener(request, timeout=45) as response:
                content = response.read().decode('UTF-8')
                content_type = response.headers.get('Content-Type', 'unknown')
            if content.strip():
                try:
                    data = json.loads(content)
                except json.JSONDecodeError as error:
                    excerpt = ' '.join(content.split())[:120]
                    raise ValueError(
                        'Non-JSON response from {} ({}): {}'.format(
                            url, content_type, excerpt)) from error
            else:
                data = []
            sleep(delay)
            return data
        except urllib.error.HTTPError as error:
            body = error.read().decode('UTF-8', errors='replace')
            excerpt = ' '.join(body.split())[:160]
            raise ValueError('HTTP {} from {}: {}'.format(
                error.code, url, excerpt)) from error
        except (urllib.error.URLError, TimeoutError) as error:
            if attempt == 2:
                raise
            reason = getattr(error, 'reason', error)
            print('WARNING: retrying space-weather request after {}'.format(reason))
            sleep(delay * 5)


def build_kp(kp_json):
    three_hour_rows = []
    intervals = []
    daily_max = {}
    daily_status = {}
    times = kp_json.get('datetime', [])
    statuses = kp_json.get('status') or [KP_STATUS_DEFINITIVE] * len(times)

    for time_text, kp_value, status in zip(times, kp_json.get('Kp', []), statuses):
        interval_start = parse_time(time_text)
        try:
            kp_value = float(kp_value)
        except (TypeError, ValueError):
            continue
        if interval_start is None or not 0 <= kp_value <= 9:
            continue

        status = status or KP_STATUS_PRELIMINARY
        centre = interval_start + datetime.timedelta(minutes=90)
        intervals.append((interval_start, kp_value))
        three_hour_rows.append([
            centre.strftime(TIME_FORMAT), '{:.3f}'.format(kp_value), storm_level(kp_value),
            status])
        day = interval_start.date()
        daily_max[day] = max(daily_max.get(day, 0.0), kp_value)
        if status != KP_STATUS_DEFINITIVE:
            daily_status[day] = KP_STATUS_PRELIMINARY

    daily_rows = [
        [day.strftime('%Y-%m-%d 12:00:00'), '{:.3f}'.format(kp_value), storm_level(kp_value),
         daily_status.get(day, KP_STATUS_DEFINITIVE)]
        for day, kp_value in sorted(daily_max.items())]
    return three_hour_rows, daily_rows, intervals


def storm_peak_kp(start, intervals, fallback):
    window_start = start - datetime.timedelta(hours=3)
    window_end = start + datetime.timedelta(hours=36)
    values = [kp for interval_start, kp in intervals
              if window_start <= interval_start <= window_end]
    return max(values) if values else fallback


def build_storms(storms_json, shocks_json, intervals):
    earth_shocks = {
        shock['activityID']: shock for shock in shocks_json
        if shock.get('location') == 'Earth' and shock.get('activityID')
    }
    rows = []

    for storm in storms_json:
        start = parse_time(storm.get('startTime'))
        if start is None:
            continue
        kp_values = [entry.get('kpIndex') for entry in storm.get('allKpIndex') or []
                     if entry.get('kpIndex') is not None]
        fallback = max(kp_values) if kp_values else 0.0
        max_kp = storm_peak_kp(start, intervals, fallback)
        linked_ids = [event['activityID'] for event in storm.get('linkedEvents') or []
                      if event.get('activityID')]
        shock_ids = [activity_id for activity_id in linked_ids if activity_id in earth_shocks]
        cme_ids = {activity_id for activity_id in linked_ids if '-CME-' in activity_id}

        for shock_id in shock_ids:
            for event in earth_shocks[shock_id].get('linkedEvents') or []:
                activity_id = event.get('activityID') or ''
                if '-CME-' in activity_id:
                    cme_ids.add(activity_id)

        cme_times = sorted(
            event_time for event_time in (activity_time(item) for item in cme_ids)
            if event_time and event_time <= start)
        shock_times = sorted(
            event_time for event_time in
            (parse_time(earth_shocks[item].get('eventTime')) for item in shock_ids)
            if event_time)
        rows.append([
            start.strftime(TIME_FORMAT), '{:.3f}'.format(max_kp), storm_level(max_kp),
            ';'.join(item.strftime(TIME_FORMAT) for item in cme_times),
            ';'.join(item.strftime(TIME_FORMAT) for item in shock_times),
            storm.get('gstID', ''),
        ])

    return sorted(rows, key=lambda row: row[0])


def fetch_range(start_date, end_date, delay=2.0):
    date_range = urllib.parse.urlencode({
        'start': start_date.isoformat() + 'T00:00:00Z',
        'end': end_date.isoformat() + 'T23:59:59Z',
        'index': 'Kp',
    })
    kp_json = fetch_json(GFZ_URL + '?' + date_range, delay=delay)
    if not isinstance(kp_json, dict):
        raise ValueError('Unexpected space-weather response format')

    storms_json = []
    shocks_json = []
    chunk_start = start_date
    while chunk_start <= end_date:
        chunk_end = min(
            chunk_start + datetime.timedelta(days=DONKI_MAX_RANGE_DAYS - 1), end_date)
        donki_range = urllib.parse.urlencode({
            'startDate': chunk_start.isoformat(), 'endDate': chunk_end.isoformat()})
        chunk_storms = fetch_json(DONKI_URL + 'GST?' + donki_range, delay=delay)
        chunk_shocks = fetch_json(DONKI_URL + 'IPS?' + donki_range, delay=delay)
        if not isinstance(chunk_storms, list) or not isinstance(chunk_shocks, list):
            raise ValueError('Unexpected space-weather response format from DONKI')
        storms_json.extend(chunk_storms)
        shocks_json.extend(chunk_shocks)
        chunk_start = chunk_end + datetime.timedelta(days=1)

    three_hour_rows, _, intervals = build_kp(kp_json)
    return three_hour_rows, build_storms(storms_json, shocks_json, intervals)


def cache_paths(base_path):
    directory = os.path.join(base_path, 'data', 'spaceweather')
    return {
        'directory': directory,
        'kp_3hour': os.path.join(directory, 'kp_3hour.csv'),
        'kp_daily': os.path.join(directory, 'kp_daily.csv'),
        'storms': os.path.join(directory, 'storms.csv'),
        'coverage': os.path.join(directory, 'coverage.json'),
    }


def _read_csv_rows(path):
    if not os.path.isfile(path):
        return []
    with open(path, mode='r', encoding='UTF-8', newline='') as input_file:
        return list(csv.reader(input_file))[1:]


def _read_coverage(path):
    try:
        with open(path, mode='r', encoding='UTF-8') as coverage_file:
            metadata = json.load(coverage_file)
        return (datetime.date.fromisoformat(metadata['start_date']),
                datetime.date.fromisoformat(metadata['end_date']))
    except (OSError, KeyError, TypeError, ValueError, json.JSONDecodeError):
        return None


def _merge_requested_rows(existing_rows, incoming_rows, ranges):
    rows = {}
    for row in existing_rows:
        try:
            row_date = datetime.datetime.strptime(row[0], TIME_FORMAT).date()
        except (IndexError, ValueError):
            continue
        if not any(start <= row_date <= end for start, end in ranges):
            rows[row[0]] = row
    for row in incoming_rows:
        rows[row[0]] = row
    return [rows[key] for key in sorted(rows)]


def _atomic_write_files(contents_by_path):
    staged_paths = {}
    backup_paths = {}
    original_paths = {}
    replaced_paths = []
    try:
        for path, contents in contents_by_path.items():
            directory = os.path.dirname(path)
            os.makedirs(directory, exist_ok=True)
            original_paths[path] = None
            if os.path.isfile(path):
                with open(path, 'rb') as original_file:
                    original_paths[path] = original_file.read()
            file_descriptor, temporary_path = tempfile.mkstemp(
                prefix='.space-weather-', dir=directory)
            with os.fdopen(file_descriptor, 'wb') as staged_file:
                staged_file.write(contents)
            os.chmod(temporary_path, 0o644)
            staged_paths[path] = temporary_path

            if original_paths[path] is not None:
                file_descriptor, backup_path = tempfile.mkstemp(
                    prefix='.space-weather-backup-', dir=directory)
                with os.fdopen(file_descriptor, 'wb') as backup_file:
                    backup_file.write(original_paths[path])
                os.chmod(backup_path, 0o644)
                backup_paths[path] = backup_path

        for path, temporary_path in staged_paths.items():
            os.replace(temporary_path, path)
            replaced_paths.append(path)
    except OSError:
        for path in reversed(replaced_paths):
            if path in backup_paths:
                os.replace(backup_paths[path], path)
            elif os.path.exists(path):
                os.remove(path)
        raise
    finally:
        for temporary_path in list(staged_paths.values()) + list(backup_paths.values()):
            if os.path.exists(temporary_path):
                os.remove(temporary_path)


def _csv_bytes(header, rows):
    output = io.StringIO(newline='')
    writer = csv.writer(output)
    writer.writerow(header)
    writer.writerows(rows)
    return output.getvalue().encode('UTF-8')


def _json_bytes(value):
    return (json.dumps(value, indent=2, sort_keys=True) + '\n').encode('UTF-8')


def _oldest_provisional_date(kp_rows):
    oldest = None
    for row in kp_rows:
        # rows cached before the Status column existed were definitive-only
        if len(row) < 4 or row[3] == KP_STATUS_DEFINITIVE:
            continue
        try:
            row_date = datetime.datetime.strptime(row[0], TIME_FORMAT).date()
        except ValueError:
            continue
        if oldest is None or row_date < oldest:
            oldest = row_date
    return oldest


def _request_ranges(start_date, end_date, previous_coverage, refresh_days,
                    oldest_provisional=None):
    if previous_coverage is None:
        return [(start_date, end_date)]

    covered_start, covered_end = previous_coverage
    if end_date < covered_start:
        return [(start_date, end_date)]

    ranges = []
    if start_date < covered_start:
        ranges.append((start_date, covered_start - datetime.timedelta(days=1)))

    refresh_start = max(start_date, end_date - datetime.timedelta(days=refresh_days - 1))
    if oldest_provisional is not None:
        refresh_start = max(start_date, min(refresh_start, oldest_provisional))
    if covered_end < refresh_start - datetime.timedelta(days=1):
        ranges.append((covered_end + datetime.timedelta(days=1), refresh_start - datetime.timedelta(days=1)))
    ranges.append((refresh_start, end_date))

    merged = []
    for range_start, range_end in sorted(ranges):
        if range_start > range_end:
            continue
        if merged and range_start <= merged[-1][1] + datetime.timedelta(days=1):
            merged[-1] = (merged[-1][0], max(merged[-1][1], range_end))
        else:
            merged.append((range_start, range_end))
    return merged


def update_cache(base_path, start_date, end_date, refresh_days=REFRESH_DAYS,
                 range_fetcher=None):
    if start_date > end_date:
        raise ValueError('Space-weather start date must be on or before end date')
    paths = cache_paths(base_path)
    previous_coverage = _read_coverage(paths['coverage'])
    existing_kp = _read_csv_rows(paths['kp_3hour'])
    ranges = _request_ranges(start_date, end_date, previous_coverage, refresh_days,
                             _oldest_provisional_date(existing_kp))
    range_fetcher = range_fetcher or fetch_range
    incoming_kp = []
    incoming_storms = []

    for range_start, range_end in ranges:
        kp_rows, storm_rows = range_fetcher(range_start, range_end)
        incoming_kp.extend(kp_rows)
        incoming_storms.extend(storm_rows)

    merged_kp = _merge_requested_rows(existing_kp, incoming_kp, ranges)
    # Rows cached before the Status column existed were definitive-only.
    merged_kp = [row if len(row) >= 4 else list(row) + [KP_STATUS_DEFINITIVE]
                 for row in merged_kp]
    merged_storms = _merge_requested_rows(_read_csv_rows(paths['storms']), incoming_storms, ranges)
    intervals = []
    for row in merged_kp:
        try:
            centre = datetime.datetime.strptime(row[0], TIME_FORMAT)
            intervals.append((centre - datetime.timedelta(minutes=90), float(row[1]), row[3]))
        except (IndexError, ValueError):
            continue
    daily_rows = build_kp({
        'datetime': [item[0].strftime('%Y-%m-%dT%H:%M:%SZ') for item in intervals],
        'Kp': [item[1] for item in intervals],
        'status': [item[2] for item in intervals],
    })[1]

    if previous_coverage and end_date < previous_coverage[0]:
        covered_start, covered_end = start_date, end_date
    else:
        covered_start = min(start_date, previous_coverage[0]) if previous_coverage else start_date
        covered_end = max(end_date, previous_coverage[1]) if previous_coverage else end_date
    coverage = {
        'start_date': covered_start.isoformat(),
        'end_date': covered_end.isoformat(),
        'updated_at_utc': datetime.datetime.now(datetime.timezone.utc).replace(
            microsecond=0).isoformat(),
    }
    _atomic_write_files({
        paths['kp_3hour']: _csv_bytes(['DateTime', 'Kp', 'GLevel', 'Status'], merged_kp),
        paths['kp_daily']: _csv_bytes(['DateTime', 'MaxKp', 'GLevel', 'Status'], daily_rows),
        paths['storms']: _csv_bytes(
            ['StormStart', 'MaxKp', 'GLevel', 'CMELaunches', 'ShockArrivals', 'GSTID'],
            merged_storms),
        paths['coverage']: _json_bytes(coverage),
    })
    log_message('space_weather.py', 'Cached space weather {} through {} ({} request range(s))'.format(
        covered_start, covered_end, len(ranges)))
    return paths