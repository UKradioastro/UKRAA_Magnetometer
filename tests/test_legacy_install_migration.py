import os
import sys
import tempfile
import unittest


SCRIPTS_PATH = os.path.join(os.path.dirname(__file__), '..', 'scripts')
sys.path.insert(0, os.path.abspath(SCRIPTS_PATH))

import MigrateLegacyInstall


class LegacyInstallMigrationTests(unittest.TestCase):
    def setUp(self):
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.base_path = self.temporary_directory.name
        self.log_directory = os.path.join(self.base_path, 'logfiles')
        self.scripts_directory = os.path.join(self.base_path, 'scripts')
        self.install_directory = os.path.join(self.base_path, 'install')
        os.makedirs(self.log_directory)
        os.makedirs(self.scripts_directory)
        os.makedirs(self.install_directory)

    def tearDown(self):
        self.temporary_directory.cleanup()

    def test_migrates_old_and_rotated_logs_without_losing_content(self):
        old_current = os.path.join(
            self.log_directory, 'log-MagnetometerACM0.txt')
        new_current = os.path.join(self.log_directory, 'log-Magnetometer.txt')
        old_rotated = os.path.join(
            self.log_directory, 'log-MagnetometerACM0-1.txt')
        with open(old_current, mode='w', encoding='utf-8') as log_file:
            log_file.write('legacy entry\n')
        with open(new_current, mode='w', encoding='utf-8') as log_file:
            log_file.write('new entry\n')
        with open(old_rotated, mode='w', encoding='utf-8') as log_file:
            log_file.write('rotated legacy entry\n')

        migrated = MigrateLegacyInstall.migrate_legacy_logs(self.log_directory)

        with open(new_current, mode='r', encoding='utf-8') as log_file:
            self.assertEqual(log_file.read(), 'new entry\nlegacy entry\n')
        with open(os.path.join(
                self.log_directory, 'log-Magnetometer-1.txt'),
                mode='r', encoding='utf-8') as log_file:
            self.assertEqual(log_file.read(), 'rotated legacy entry\n')
        self.assertFalse(os.path.exists(old_current))
        self.assertFalse(os.path.exists(old_rotated))
        self.assertEqual(len(migrated), 2)

    def test_removes_only_explicit_legacy_names(self):
        legacy_script = os.path.join(self.scripts_directory, 'GetDataRawACM0.py')
        unrelated_script = os.path.join(self.scripts_directory, 'local-helper.py')
        legacy_service = os.path.join(
            self.install_directory, 'PicoMagnetometerACM0.service')
        for file_path in (legacy_script, unrelated_script, legacy_service):
            with open(file_path, mode='w', encoding='utf-8'):
                pass

        removed = MigrateLegacyInstall.remove_legacy_files(self.base_path)

        self.assertFalse(os.path.exists(legacy_script))
        self.assertFalse(os.path.exists(legacy_service))
        self.assertTrue(os.path.exists(unrelated_script))
        self.assertEqual(len(removed), 2)


if __name__ == '__main__':
    unittest.main()