import csv
import datetime
import os
import sys
import tempfile
import unittest


SCRIPTS_PATH = os.path.join(os.path.dirname(__file__), '..', 'scripts')
sys.path.insert(0, os.path.abspath(SCRIPTS_PATH))

import ProcessDailySummary
import GetPeriodPlotAvailability
import magnetometer_common


class ProcessDailySummaryTests(unittest.TestCase):
    def test_period_availability_requires_complete_window(self):
        end_date = datetime.date(2026, 9, 24)
        complete_dates = {
            end_date - datetime.timedelta(days=day_offset)
            for day_offset in range(7)
        }
        period_options = {
            'week': True,
            'month': True,
            '3month': False,
            '6month': False,
            'year': False,
        }

        periods = GetPeriodPlotAvailability.build_period_status(
            end_date, complete_dates, period_options)

        self.assertTrue(periods['week']['available'])
        self.assertEqual(periods['week']['valid_days'], 7)
        self.assertFalse(periods['month']['available'])
        self.assertEqual(periods['month']['valid_days'], 7)

    def test_period_availability_uses_every_threshold(self):
        end_date = datetime.date(2026, 9, 24)
        period_options = {
            period_name: True
            for period_name in GetPeriodPlotAvailability.PERIOD_DAY_COUNTS
        }

        for period_name, required_days in GetPeriodPlotAvailability.PERIOD_DAY_COUNTS.items():
            complete_dates = {
                end_date - datetime.timedelta(days=day_offset)
                for day_offset in range(required_days)
            }
            periods = GetPeriodPlotAvailability.build_period_status(
                end_date, complete_dates, period_options)

            self.assertTrue(periods[period_name]['available'])
            self.assertEqual(periods[period_name]['valid_days'], required_days)

            complete_dates.remove(end_date - datetime.timedelta(days=required_days - 1))
            periods = GetPeriodPlotAvailability.build_period_status(
                end_date, complete_dates, period_options)
            self.assertFalse(periods[period_name]['available'])
            self.assertEqual(periods[period_name]['valid_days'], required_days - 1)

    def test_reads_period_plot_options(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            config_directory = os.path.join(temporary_directory, 'config')
            os.makedirs(config_directory)
            with open(os.path.join(config_directory, 'plot.ini'), mode='w', encoding='UTF-8') as config_file:
                config_file.write('[plots]\nplot_week = true\nplot_3month = yes\nplot_year = 1\n')

            self.assertEqual(
                magnetometer_common.get_period_plot_options(temporary_directory),
                {'week': True, 'month': False, '3month': True, '6month': False, 'year': True})

    def test_writes_daily_and_combined_summaries(self):
        target_date = datetime.date(2026, 9, 24)

        with tempfile.TemporaryDirectory() as temporary_directory:
            minute_directory = os.path.join(
                temporary_directory, 'data', 'minute', '2026', '2026-09')
            os.makedirs(minute_directory)
            minute_path = os.path.join(minute_directory, '2026-09-24.csv')

            with open(minute_path, mode='w', encoding='UTF-8', newline='') as minute_file:
                writer = csv.writer(minute_file)
                writer.writerows([
                    ['2026-09-24 00:00:00', '0', '0', '0', '100', '200', '300', '10', '5'],
                    ['2026-09-24 00:01:00', '0', '0', '0', '110', '220', '330', '12', '8'],
                    ['2026-09-24 00:02:00', '0', '0', '0', 'nan', '0', '0', '15', '2'],
                ])

            ProcessDailySummary.write_daily_summary(
                temporary_directory, target_date)
            ProcessDailySummary.rebuild_combined_summary(temporary_directory)

            summary_path = os.path.join(
                temporary_directory, 'data', 'daily', '2026', '2026-09', '2026-09-24.csv')
            with open(summary_path, mode='r', encoding='UTF-8', newline='') as summary_file:
                summary_row = next(csv.reader(summary_file))

            self.assertEqual(summary_row[0], '2026-09-24 12:00:00')
            self.assertEqual(summary_row[1:6], ['105.0', '210.0', '315.0', '11.0', '8.0'])
            self.assertEqual(summary_row[6], '234.8')
            self.assertEqual(summary_row[7], '63.43')
            self.assertEqual(summary_row[8], '392.9')
            self.assertEqual(summary_row[9], '53.30')
            self.assertEqual(summary_row[10], '2')
            self.assertEqual(summary_row[11], '0.1')

            combined_path = os.path.join(temporary_directory, 'data', 'daily', 'summary.csv')
            with open(combined_path, mode='r', encoding='UTF-8', newline='') as combined_file:
                combined_rows = list(csv.reader(combined_file))

            self.assertEqual(combined_rows[0], ProcessDailySummary.SUMMARY_HEADER)
            self.assertEqual(combined_rows[1], summary_row)


if __name__ == '__main__':
    unittest.main()