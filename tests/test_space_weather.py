import csv
import datetime
import io
import json
import os
import re
import sys
import tempfile
import unittest
import urllib.parse
from contextlib import redirect_stdout
from types import SimpleNamespace
from unittest.mock import patch


SCRIPTS_PATH = os.path.join(os.path.dirname(__file__), '..', 'scripts')
sys.path.insert(0, os.path.abspath(SCRIPTS_PATH))

import space_weather
import PlotPeriodSpaceWeather
import magnetometer_common
import UpdatePeriodSpaceWeather


class SpaceWeatherTests(unittest.TestCase):
    def test_build_kp_centres_three_hour_bins_and_computes_daily_max(self):
        three_hour_rows, daily_rows, intervals = space_weather.build_kp({
            'datetime': [
                '2023-04-23T00:00Z',
                '2023-04-23T03:00Z',
                '2023-04-23T06:00Z',
                '2023-04-23T09:00Z',
            ],
            'Kp': [1.0, 8.333, None, 12.0],
        })

        self.assertEqual(three_hour_rows, [
            ['2023-04-23 01:30:00', '1.000', 0, 'def'],
            ['2023-04-23 04:30:00', '8.333', 4, 'def'],
        ])
        self.assertEqual(daily_rows, [['2023-04-23 12:00:00', '8.333', 4, 'def']])
        self.assertEqual(intervals, [
            (datetime.datetime(2023, 4, 23, 0), 1.0),
            (datetime.datetime(2023, 4, 23, 3), 8.333),
        ])

    def test_build_storms_follows_earth_shock_to_cme_and_uses_definitive_kp(self):
        cme_id = '2023-04-21T18:12:00-CME-001'
        shock_id = '2023-04-23T17:00:00-IPS-001'
        storm = {
            'gstID': '2023-04-23T18:00:00-GST-001',
            'startTime': '2023-04-23T18:00Z',
            'allKpIndex': [{'kpIndex': 7.0}],
            'linkedEvents': [{'activityID': shock_id}],
        }
        shock = {
            'activityID': shock_id,
            'location': 'Earth',
            'eventTime': '2023-04-23T17:00Z',
            'linkedEvents': [{'activityID': cme_id}],
        }

        rows = space_weather.build_storms(
            [storm], [shock], [(datetime.datetime(2023, 4, 23, 18), 8.333)])

        self.assertEqual(rows, [[
            '2023-04-23 18:00:00', '8.333', 4,
            '2023-04-21 18:12:00', '2023-04-23 17:00:00',
            '2023-04-23T18:00:00-GST-001',
        ]])

    def test_storm_level_uses_noaa_g_scale_thresholds(self):
        self.assertEqual([space_weather.storm_level(value) for value in
                          (4.0, 4.667, 5.667, 6.667, 7.667, 8.667, 9.0)],
                         [0, 1, 2, 3, 4, 5, 5])

    def test_fetch_range_includes_preliminary_kp_and_records_status(self):
        with patch('space_weather.fetch_json', side_effect=[
                {'datetime': ['2023-04-23T15:00Z', '2023-04-23T18:00Z'],
                 'Kp': [5.0, 8.333], 'status': ['def', 'pre']}, [], []]) as fetch:
            kp_rows, storm_rows = space_weather.fetch_range(
                datetime.date(2023, 4, 23), datetime.date(2023, 4, 23))

        query = urllib.parse.parse_qs(urllib.parse.urlparse(fetch.call_args_list[0].args[0]).query)
        self.assertNotIn('status', query)
        self.assertEqual(query['index'], ['Kp'])
        self.assertTrue(fetch.call_args_list[1].args[0].startswith(
            'https://ccmc.gsfc.nasa.gov/DONKI-API/get/GST?'))
        self.assertTrue(fetch.call_args_list[2].args[0].startswith(
            'https://ccmc.gsfc.nasa.gov/DONKI-API/get/IPS?'))
        self.assertEqual(kp_rows, [
            ['2023-04-23 16:30:00', '5.000', 1, 'def'],
            ['2023-04-23 19:30:00', '8.333', 4, 'pre'],
        ])
        self.assertEqual(storm_rows, [])

    def test_cache_refetches_from_oldest_preliminary_kp_beyond_refresh_window(self):
        with tempfile.TemporaryDirectory() as base_path:
            start = datetime.date(2023, 1, 1)
            space_weather.update_cache(
                base_path, start, datetime.date(2023, 1, 10), refresh_days=2,
                range_fetcher=lambda _start, _end: ([
                    ['2023-01-02 01:30:00', '2.000', 0, 'def'],
                    ['2023-01-04 01:30:00', '3.000', 0, 'pre'],
                    ['2023-01-09 01:30:00', '3.000', 0, 'pre'],
                ], []))
            calls = []

            def refresh_fetch(range_start, range_end):
                calls.append((range_start, range_end))
                return ([['2023-01-04 01:30:00', '3.333', 0, 'def'],
                         ['2023-01-09 01:30:00', '3.000', 0, 'def']], [])

            paths = space_weather.update_cache(
                base_path, start, datetime.date(2023, 1, 11), refresh_days=2,
                range_fetcher=refresh_fetch)

            self.assertEqual(calls, [(datetime.date(2023, 1, 4), datetime.date(2023, 1, 11))])
            with open(paths['kp_3hour'], mode='r', encoding='UTF-8', newline='') as cache_file:
                rows = list(csv.reader(cache_file))
            self.assertEqual(rows[0], ['DateTime', 'Kp', 'GLevel', 'Status'])
            self.assertEqual(rows[1:], [
                ['2023-01-02 01:30:00', '2.000', '0', 'def'],
                ['2023-01-04 01:30:00', '3.333', '0', 'def'],
                ['2023-01-09 01:30:00', '3.000', '0', 'def'],
            ])
            with open(paths['kp_daily'], mode='r', encoding='UTF-8', newline='') as daily_file:
                daily_rows = list(csv.reader(daily_file))
            self.assertEqual(daily_rows[0], ['DateTime', 'MaxKp', 'GLevel', 'Status'])
            self.assertEqual([row[3] for row in daily_rows[1:]], ['def', 'def', 'def'])

            calls.clear()
            space_weather.update_cache(
                base_path, start, datetime.date(2023, 1, 12), refresh_days=2,
                range_fetcher=refresh_fetch)
            self.assertEqual(calls, [(datetime.date(2023, 1, 11), datetime.date(2023, 1, 12))])

    def test_legacy_cache_rows_without_status_are_treated_as_definitive(self):
        self.assertIsNone(space_weather._oldest_provisional_date([
            ['2023-01-02 01:30:00', '2.000', '0'],
        ]))

    def test_cache_upgrades_legacy_rows_and_marks_preliminary_days(self):
        with tempfile.TemporaryDirectory() as base_path:
            paths = space_weather.cache_paths(base_path)
            os.makedirs(paths['directory'])
            with open(paths['kp_3hour'], mode='w', encoding='UTF-8', newline='') as cache_file:
                cache_file.write('DateTime,Kp,GLevel\n2023-01-01 22:30:00,2.000,0\n')
            with open(paths['coverage'], mode='w', encoding='UTF-8') as coverage_file:
                coverage_file.write('{"start_date": "2023-01-01", "end_date": "2023-01-01"}')

            space_weather.update_cache(
                base_path, datetime.date(2023, 1, 1), datetime.date(2023, 1, 2),
                refresh_days=1, range_fetcher=lambda _start, _end: ([
                    ['2023-01-02 01:30:00', '5.000', 1, 'def'],
                    ['2023-01-02 04:30:00', '3.000', 0, 'pre'],
                ], []))

            with open(paths['kp_3hour'], mode='r', encoding='UTF-8', newline='') as cache_file:
                rows = list(csv.reader(cache_file))
            with open(paths['kp_daily'], mode='r', encoding='UTF-8', newline='') as daily_file:
                daily_rows = list(csv.reader(daily_file))
        self.assertEqual(rows[1], ['2023-01-01 22:30:00', '2.000', '0', 'def'])
        self.assertEqual(daily_rows[1:], [
            ['2023-01-01 12:00:00', '2.000', '0', 'def'],
            ['2023-01-02 12:00:00', '5.000', '1', 'pre'],
        ])

    def test_fetch_range_chunks_donki_requests_at_sixty_days(self):
        start = datetime.date(2025, 9, 25)
        end = datetime.date(2026, 10, 1)
        with patch('space_weather.fetch_json', side_effect=[{'datetime': [], 'Kp': []}] +
                   [[] for _ in range(14)]) as fetch:
            kp_rows, storm_rows = space_weather.fetch_range(start, end, delay=0)

        self.assertEqual(kp_rows, [])
        self.assertEqual(storm_rows, [])
        self.assertEqual(fetch.call_count, 15)
        for index in range(1, fetch.call_count, 2):
            gst_url = fetch.call_args_list[index].args[0]
            ips_url = fetch.call_args_list[index + 1].args[0]
            gst_query = urllib.parse.parse_qs(urllib.parse.urlparse(gst_url).query)
            ips_query = urllib.parse.parse_qs(urllib.parse.urlparse(ips_url).query)
            self.assertLessEqual(
                (datetime.date.fromisoformat(gst_query['endDate'][0]) -
                 datetime.date.fromisoformat(gst_query['startDate'][0])).days, 59)
            self.assertEqual(gst_query['startDate'], ips_query['startDate'])
            self.assertEqual(gst_query['endDate'], ips_query['endDate'])

    def test_http_error_reports_server_body(self):
        http_error = __import__('urllib.error').error.HTTPError(
            'https://example.test/GST', 400, 'Bad Request', {},
            __import__('io').BytesIO(b'API Error: Date range cannot exceed 60 days.'))
        with self.assertRaisesRegex(ValueError, 'Date range cannot exceed 60 days'):
            space_weather.fetch_json(
                'https://example.test/GST', delay=0,
                opener=lambda *_args, **_kwargs: (_ for _ in ()).throw(http_error),
                sleep=lambda _delay: None)

    def test_non_json_service_response_names_the_endpoint(self):
        class HtmlResponse:
            headers = {'Content-Type': 'text/html; charset=UTF-8'}

            def __enter__(self):
                return self

            def __exit__(self, *_args):
                return False

            def read(self):
                return b'<!DOCTYPE html><title>Service moved</title>'

        with self.assertRaisesRegex(ValueError, 'Non-JSON response from https://example.test/GST'):
            space_weather.fetch_json(
                'https://example.test/GST', delay=0,
                opener=lambda *_args, **_kwargs: HtmlResponse(), sleep=lambda _delay: None)

    def test_plot_script_contains_kp_storm_cme_and_source_context(self):
        window_start = datetime.datetime(2023, 4, 1)
        window_end = datetime.datetime(2023, 4, 30, 23, 59, 59)
        storm = {
            'start': datetime.datetime(2023, 4, 23, 18),
            'kp': 8.333,
            'level': 4,
            'cmes': [datetime.datetime(2023, 4, 21, 18, 12)],
            'shocks': [datetime.datetime(2023, 4, 23, 17)],
        }

        script = PlotPeriodSpaceWeather.build_script(
            'HDZ', 'month', window_start, window_end,
            'data/daily/summary.csv', 'data/spaceweather/kp_3hour.csv', 10800,
            [storm], 'plots/month/HDZ/2023/2023-04/2023-04-30.png', True)

        self.assertIn('set multiplot layout 4,1', script)
        self.assertIn('GFZ Potsdam (CC BY 4.0)', script)
        self.assertIn('NASA CCMC DONKI', script)
        self.assertIn('G4 8+', script)
        self.assertIn('CME launch to storm', script)
        self.assertIn('Shock at Earth', script)
        self.assertIn('using 1:7', script)
        self.assertNotIn('\n+', script)

    def test_long_view_labels_only_g3_and_stronger(self):
        storms = [
            {'start': datetime.datetime(2023, 3, 1), 'kp': 6.0, 'level': 2,
             'cmes': [], 'shocks': []},
            {'start': datetime.datetime(2023, 11, 1), 'kp': 7.0, 'level': 3,
             'cmes': [], 'shocks': []},
        ]
        script = PlotPeriodSpaceWeather.build_script(
            'XYZ', 'year', datetime.datetime(2023, 1, 1),
            datetime.datetime(2023, 12, 31, 23, 59, 59),
            'summary.csv', 'kp_daily.csv', 86400, storms, 'year.png', True)

        self.assertNotIn('G2 6o', script)
        self.assertIn('G3 7o', script)
        self.assertEqual(script.count('set arrow from first'), 2)

    def test_plot_command_writes_existing_archive_and_web_paths(self):
        with tempfile.TemporaryDirectory() as base_path:
            summary_path = os.path.join(base_path, 'data', 'daily', 'summary.csv')
            os.makedirs(os.path.dirname(summary_path))
            with open(summary_path, mode='w', encoding='UTF-8') as summary_file:
                summary_file.write('DateTime,X,Y,Z\n')
            target_date = datetime.date(2023, 1, 7)
            archive_path = os.path.join(
                base_path, 'plots', 'week', 'XYZ', '2023', '2023-01', '2023-01-07.png')

            def fake_gnuplot(_command, **_kwargs):
                os.makedirs(os.path.dirname(archive_path), exist_ok=True)
                with open(archive_path, 'wb') as plot_file:
                    plot_file.write(b'png-data')
                return SimpleNamespace(returncode=0, stderr='')

            with patch.object(PlotPeriodSpaceWeather, 'parse_arguments', return_value=SimpleNamespace(
                    period='week', family='XYZ', target_date=target_date)), \
                    patch.object(PlotPeriodSpaceWeather, 'get_base_path', return_value=base_path), \
                    patch.object(PlotPeriodSpaceWeather.subprocess, 'run', side_effect=fake_gnuplot):
                self.assertEqual(PlotPeriodSpaceWeather.main(), 0)

            temp_path = os.path.join(base_path, 'temp', 'periods', 'week', 'XYZ.png')
            with open(temp_path, 'rb') as plot_file:
                self.assertEqual(plot_file.read(), b'png-data')
            self.assertTrue(os.path.isfile(archive_path))

    def test_preliminary_kp_is_shaded_lighter_and_listed_in_key(self):
        with tempfile.TemporaryDirectory() as base_path:
            kp_path = os.path.join(base_path, 'kp_daily.csv')
            with open(kp_path, mode='w', encoding='UTF-8') as kp_file:
                kp_file.write('DateTime,MaxKp,GLevel,Status\n'
                              '2023-04-01 12:00:00,2.000,0,def\n'
                              '2023-04-02 12:00:00,3.000,0,pre\n')
            window = (datetime.datetime(2023, 4, 1), datetime.datetime(2023, 4, 2, 23, 59, 59))
            self.assertTrue(PlotPeriodSpaceWeather.has_kp_data(kp_path, *window))
            self.assertTrue(PlotPeriodSpaceWeather.has_preliminary_kp_data(kp_path, *window))
            self.assertFalse(PlotPeriodSpaceWeather.has_preliminary_kp_data(
                kp_path, window[0], datetime.datetime(2023, 4, 1, 23, 59, 59)))

        script = PlotPeriodSpaceWeather.build_script(
            'XYZ', '3month', window[0], window[1], 'summary.csv', kp_path, 86400, [],
            'period.png', True, kp_preliminary=True)
        self.assertIn('(strcol(4) eq "def") && $3==0', script)
        self.assertIn('(strcol(4) ne "def") && $3==0 ? $2 : 1/0) with boxes lc rgb "#2f6f44" fs transparent solid 0.35', script)
        self.assertIn('title "Preliminary Kp"', script)

        definitive_only = PlotPeriodSpaceWeather.build_script(
            'XYZ', '3month', window[0], window[1], 'summary.csv', kp_path, 86400, [],
            'period.png', True)
        self.assertNotIn('strcol(4)', definitive_only)
        self.assertNotIn('Preliminary Kp', definitive_only)

    def test_plot_script_marks_missing_kp_without_losing_magnetic_panels(self):
        script = PlotPeriodSpaceWeather.build_script(
            'XYZ', 'week', datetime.datetime(2023, 4, 1),
            datetime.datetime(2023, 4, 7, 23, 59, 59),
            'summary.csv', 'missing-kp.csv', 10800, [], 'period.png', False)

        self.assertIn('set multiplot layout 4,1', script)
        self.assertIn('No historical Kp data available for this window', script)
        self.assertIn('using 1:2', script)

    def test_spaceweather_plot_option_defaults_off_and_has_environment_override(self):
        with tempfile.TemporaryDirectory() as base_path:
            self.assertFalse(magnetometer_common.get_period_spaceweather_option(base_path))
            config_directory = os.path.join(base_path, 'config')
            os.makedirs(config_directory)
            config_path = os.path.join(config_directory, 'plot.ini')
            with open(config_path, mode='w', encoding='UTF-8') as config_file:
                config_file.write('[plots]\nplot_period_spaceweather = true\n')
            self.assertTrue(magnetometer_common.get_period_spaceweather_option(base_path))

            with patch.dict(os.environ, {'MAGNETOMETER_PLOT_PERIOD_SPACEWEATHER': 'false'}):
                self.assertFalse(magnetometer_common.get_period_spaceweather_option(base_path))

    def test_cache_refresh_preserves_older_rows_and_replaces_recent_range(self):
        with tempfile.TemporaryDirectory() as base_path:
            first_start = datetime.date(2023, 1, 1)
            first_end = datetime.date(2023, 1, 5)
            calls = []
            log_output = io.StringIO()

            def first_fetch(start, end):
                calls.append((start, end))
                return ([['2023-01-01 01:30:00', '2.000', 0],
                         ['2023-01-05 01:30:00', '3.000', 0]], [])

            with redirect_stdout(log_output):
                paths = space_weather.update_cache(
                    base_path, first_start, first_end, refresh_days=2,
                    range_fetcher=first_fetch)
            self.assertRegex(
                log_output.getvalue(),
                re.compile(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} : '
                           r'space_weather\.py\s+: Cached space weather'))
            self.assertEqual(calls, [(first_start, first_end)])

            def refresh_fetch(start, end):
                calls.append((start, end))
                return ([['2023-01-05 01:30:00', '4.000', 0],
                         ['2023-01-06 01:30:00', '5.000', 1]], [])

            space_weather.update_cache(
                base_path, first_start, datetime.date(2023, 1, 6), refresh_days=2,
                range_fetcher=refresh_fetch)

            self.assertEqual(calls[-1], (datetime.date(2023, 1, 5), datetime.date(2023, 1, 6)))
            with open(paths['kp_3hour'], mode='r', encoding='UTF-8', newline='') as cache_file:
                rows = list(csv.reader(cache_file))
            self.assertEqual(rows[1:], [
                ['2023-01-01 01:30:00', '2.000', '0', 'def'],
                ['2023-01-05 01:30:00', '4.000', '0', 'def'],
                ['2023-01-06 01:30:00', '5.000', '1', 'def'],
            ])
            with open(paths['coverage'], mode='r', encoding='UTF-8') as coverage_file:
                self.assertEqual(json.load(coverage_file)['end_date'], '2023-01-06')

    def test_cache_historical_rerun_does_not_claim_unfetched_dates(self):
        with tempfile.TemporaryDirectory() as base_path:
            paths = space_weather.update_cache(
                base_path,
                datetime.date(2023, 1, 1),
                datetime.date(2023, 1, 5),
                range_fetcher=lambda _start, _end: ([], []))
            calls = []

            def fetch_old_range(start, end):
                calls.append((start, end))
                return ([], [])

            space_weather.update_cache(
                base_path,
                datetime.date(2022, 12, 30),
                datetime.date(2022, 12, 31),
                range_fetcher=fetch_old_range)

            self.assertEqual(calls, [(datetime.date(2022, 12, 30), datetime.date(2022, 12, 31))])
            with open(paths['coverage'], mode='r', encoding='UTF-8') as coverage_file:
                coverage = json.load(coverage_file)
            self.assertEqual(coverage['start_date'], '2022-12-30')
            self.assertEqual(coverage['end_date'], '2022-12-31')

    def test_required_start_includes_longest_period_and_cme_lead(self):
        end_date = datetime.date(2023, 12, 31)
        start_date = UpdatePeriodSpaceWeather.required_start_date(
            end_date, {'week': True, 'year': True})
        self.assertEqual(start_date, datetime.date(2022, 12, 25))

    def test_failed_refresh_leaves_last_good_cache_unchanged(self):
        with tempfile.TemporaryDirectory() as base_path:
            paths = space_weather.update_cache(
                base_path,
                datetime.date(2023, 1, 1),
                datetime.date(2023, 1, 2),
                range_fetcher=lambda _start, _end: (
                    [['2023-01-01 01:30:00', '2.000', 0]], []))
            original_contents = {}
            for key in ('kp_3hour', 'kp_daily', 'storms', 'coverage'):
                with open(paths[key], 'rb') as cache_file:
                    original_contents[key] = cache_file.read()

            def failed_fetch(_start, _end):
                raise OSError('network unavailable')

            with self.assertRaisesRegex(OSError, 'network unavailable'):
                space_weather.update_cache(
                    base_path,
                    datetime.date(2023, 1, 1),
                    datetime.date(2023, 1, 3),
                    range_fetcher=failed_fetch)

            for key, expected in original_contents.items():
                with open(paths[key], 'rb') as cache_file:
                    self.assertEqual(cache_file.read(), expected)

    def test_failed_cache_commit_rolls_back_already_replaced_files(self):
        with tempfile.TemporaryDirectory() as base_path:
            paths = space_weather.update_cache(
                base_path,
                datetime.date(2023, 1, 1),
                datetime.date(2023, 1, 2),
                range_fetcher=lambda _start, _end: (
                    [['2023-01-01 01:30:00', '2.000', 0]], []))
            original_contents = {}
            for key in ('kp_3hour', 'kp_daily', 'storms', 'coverage'):
                with open(paths[key], 'rb') as cache_file:
                    original_contents[key] = cache_file.read()

            real_replace = os.replace
            replace_count = 0

            def fail_during_second_replace(source, target):
                nonlocal replace_count
                replace_count += 1
                if replace_count == 2:
                    raise OSError('disk write failed')
                return real_replace(source, target)

            with patch('space_weather.os.replace', side_effect=fail_during_second_replace):
                with self.assertRaisesRegex(OSError, 'disk write failed'):
                    space_weather.update_cache(
                        base_path,
                        datetime.date(2023, 1, 1),
                        datetime.date(2023, 1, 3),
                        range_fetcher=lambda _start, _end: (
                            [['2023-01-03 01:30:00', '4.000', 0]], []))

            for key, expected in original_contents.items():
                with open(paths[key], 'rb') as cache_file:
                    self.assertEqual(cache_file.read(), expected)


if __name__ == '__main__':
    unittest.main()