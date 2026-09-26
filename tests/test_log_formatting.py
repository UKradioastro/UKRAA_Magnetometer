import datetime
import os
import sys
import unittest


SCRIPTS_PATH = os.path.join(os.path.dirname(__file__), '..', 'scripts')
sys.path.insert(0, os.path.abspath(SCRIPTS_PATH))

from magnetometer_common import format_log_entry


class LogFormattingTests(unittest.TestCase):
    def test_short_and_long_source_names_put_second_colon_in_same_column(self):
        timestamp = datetime.datetime(2026, 9, 26, 12, 10, 1)
        short_entry = format_log_entry(
            timestamp, 'ProcessRolling.py', 'Started processing')
        longest_entry = format_log_entry(
            timestamp, 'updateNoaaAuroraForecast.sh', 'Started update')

        short_first_colon = short_entry.index(' : ', 19) + 1
        long_first_colon = longest_entry.index(' : ', 19) + 1
        short_second_colon = short_entry.index(':', short_first_colon + 1)
        long_second_colon = longest_entry.index(':', long_first_colon + 1)
        self.assertEqual(short_second_colon, long_second_colon)
        self.assertEqual(long_second_colon - long_first_colon - 1, 29)

    def test_longer_source_name_is_not_truncated(self):
        timestamp = datetime.datetime(2026, 9, 26, 12, 10, 1)
        source_name = 'longer-than-the-configured-width.sh'

        entry = format_log_entry(timestamp, source_name, 'message')

        self.assertIn(f' : {source_name} : message', entry)


if __name__ == '__main__':
    unittest.main()