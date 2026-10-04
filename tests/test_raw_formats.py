import csv
import datetime
import math
import os
import subprocess
import sys
import tempfile
import unittest


SCRIPTS_PATH = os.path.join(os.path.dirname(__file__), '..', 'scripts')
sys.path.insert(0, os.path.abspath(SCRIPTS_PATH))

import magnetometer_common


def parse(line):
    return magnetometer_common.parse_raw_row(line.split(','))


class RawFormatTests(unittest.TestCase):
    def test_current_eleven_column_layout(self):
        row = parse('2026-10-02 00:00:24,-0.361328,-18066.41,0.111063,5553.12,'
                    '-0.954307,-47715.37,20.8,3,G,CPicoNanoTesla')
        self.assertEqual(row['RawDateTime'], datetime.datetime(2026, 10, 2, 0, 0, 24))
        self.assertEqual(row['RawX_nT'], -18066.41)
        self.assertEqual(row['RawZ_nT'], -47715.37)
        self.assertEqual(row['RawTMP36_degC'], 20.8)
        self.assertEqual(row['RawDelta_nT'], 3.0)
        self.assertEqual(row['RawColour'], 'G')
        self.assertEqual(row['RawDetectorName'], 'CPicoNanoTesla')

    def test_voltage_only_eight_column_layout_rebuilds_nt(self):
        row = parse('2026-01-10 16:28:17,0.774656,0.629797,1.073906,19.90,25.59,'
                    '1017.93,V0.3m_Mag_PCB')
        self.assertAlmostEqual(row['RawX_nT'], 38732.8)
        self.assertAlmostEqual(row['RawY_nT'], 31489.85)
        self.assertAlmostEqual(row['RawZ_nT'], 53695.3)
        self.assertEqual(row['RawX_V'], 0.774656)
        self.assertEqual(row['RawTMP36_degC'], 19.9)
        self.assertTrue(math.isnan(row['RawDelta_nT']))
        self.assertEqual(row['RawDetectorName'], 'V0.3m_Mag_PCB')

    def test_eleven_column_environment_layout_has_no_delta(self):
        row = parse('2026-01-18 09:43:37,0.355438,17771.9,0.026891,1344.55,0.954688,'
                    '47734.404,7.70,16.79,1017.17,V0.3m_Mag_PCB')
        self.assertEqual(row['RawY_nT'], 1344.55)
        self.assertEqual(row['RawTMP36_degC'], 7.7)
        self.assertTrue(math.isnan(row['RawDelta_nT']))
        self.assertEqual(row['RawColour'], '')
        self.assertEqual(row['RawDetectorName'], 'V0.3m_Mag_PCB')

    def test_twelve_column_layout(self):
        row = parse('2026-05-29 00:00:03,0.427403,21370.16,-0.003647,-182.34,0.948800,'
                    '47440.00,26.33,30.8,1010.1,296,V7/001/KNO1')
        self.assertEqual(row['RawX_nT'], 21370.16)
        self.assertEqual(row['RawDelta_nT'], 296.0)
        self.assertEqual(row['RawColour'], '')
        self.assertEqual(row['RawDetectorName'], 'V7/001/KNO1')

    def test_thirteen_column_layout(self):
        row = parse('2026-06-13 00:00:17,0.449216,22460.78,0.022141,1107.03,0.918150,'
                    '45907.50,17.4,17.3,1011.8,154,A,V8/001/KNO')
        self.assertEqual(row['RawZ_nT'], 45907.5)
        self.assertEqual(row['RawTMP36_degC'], 17.4)
        self.assertEqual(row['RawDelta_nT'], 154.0)
        self.assertEqual(row['RawColour'], 'A')
        self.assertEqual(row['RawDetectorName'], 'V8/001/KNO')

    def test_unrecognised_or_damaged_rows_are_skipped(self):
        self.assertIsNone(parse('2026-01-10 16:28:17,0.77,0.62'))
        self.assertIsNone(parse('2026-01-10 16:28,0.774656,0.629797,1.073906,19.90,25.59,'
                                '1017.93,V0.3m_Mag_PCB'))
        self.assertIsNone(parse('2026-01-10 16:28:17,bad,0.629797,1.073906,19.90,25.59,'
                                '1017.93,V0.3m_Mag_PCB'))
        self.assertIsNone(magnetometer_common.parse_raw_row([]))

    def test_minute_and_hour_processing_accept_voltage_only_raw_file(self):
        with tempfile.TemporaryDirectory() as base_path:
            target_date = datetime.date(2026, 1, 10)
            raw_path = magnetometer_common.build_day_path(base_path, 'raw', target_date)
            os.makedirs(os.path.dirname(raw_path))
            with open(raw_path, mode='w', encoding='UTF-8', newline='') as raw_file:
                raw_file.write(
                    '2026-01-10 16:28:17,0.774656,0.629797,1.073906,19.90,25.59,1017.93,V0.3m_Mag_PCB\n'
                    '2026-01-10 16:28:22,0.775734,0.629938,1.073672,18.90,25.59,1017.93,V0.3m_Mag_PCB\n'
                    'damaged line\n')
            environment = dict(os.environ, MAGNETOMETER_BASE_PATH=base_path,
                               MAGNETOMETER_TARGET_DATE=target_date.isoformat())
            for script in ('ProcessDataRaw.py', 'ProcessDataHour.py'):
                result = subprocess.run(
                    [sys.executable, os.path.join(SCRIPTS_PATH, script)],
                    env=environment, capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stderr)

            minute_path = magnetometer_common.build_day_path(base_path, 'minute', target_date)
            with open(minute_path, mode='r', encoding='UTF-8', newline='') as minute_file:
                rows = list(csv.reader(minute_file))
            self.assertEqual(len(rows), 1440)
            sample = rows[16 * 60 + 28]
            self.assertEqual(sample[0], '2026-01-10 16:28:00')
            self.assertEqual(sample[4:7], ['38760', '31493', '53689'])
            self.assertEqual(sample[8], 'nan')
            self.assertEqual(sample[-1], 'V0.3m_Mag_PCB')
            self.assertTrue(os.path.isfile(
                magnetometer_common.build_day_path(base_path, 'hour', target_date)))


if __name__ == '__main__':
    unittest.main()
