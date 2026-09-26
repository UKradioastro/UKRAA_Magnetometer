import os
import subprocess
import sys
import tempfile
import unittest


SCRIPTS_PATH = os.path.join(os.path.dirname(__file__), '..', 'scripts')
sys.path.insert(0, os.path.abspath(SCRIPTS_PATH))

import InstallMagnetometerService


class RecordingSystemctl:
    def __init__(self, failure=None):
        self.commands = []
        self.failure = failure

    def __call__(self, command, check):
        self.commands.append(command)
        if command == self.failure:
            raise subprocess.CalledProcessError(1, command)


class ServiceInstallTests(unittest.TestCase):
    def setUp(self):
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.root = self.temporary_directory.name
        self.unit_directory = os.path.join(self.root, 'systemd')
        self.template_path = os.path.join(self.root, 'PicoMagnetometer.service')
        with open(self.template_path, mode='w', encoding='utf-8') as template:
            template.write('[Service]\nExecStart=/usr/bin/python3 GetDataRaw.py\n')

    def tearDown(self):
        self.temporary_directory.cleanup()

    def test_fresh_install_installs_enables_and_verifies_new_unit(self):
        runner = RecordingSystemctl()

        InstallMagnetometerService.install_service(
            self.template_path, self.unit_directory, runner=runner)

        current_path = os.path.join(
            self.unit_directory, InstallMagnetometerService.CURRENT_UNIT)
        self.assertTrue(os.path.isfile(current_path))
        self.assertFalse(os.path.exists(os.path.join(
            self.unit_directory, InstallMagnetometerService.LEGACY_UNIT)))
        self.assertIn(
            ['systemctl', 'enable', '--now', 'PicoMagnetometer.service'],
            runner.commands)
        self.assertIn(
            ['systemctl', 'is-active', '--quiet', 'PicoMagnetometer.service'],
            runner.commands)
        self.assertIn(
            ['systemctl', 'is-enabled', '--quiet', 'PicoMagnetometer.service'],
            runner.commands)

    def test_migrates_legacy_unit_before_installing_new_one(self):
        legacy_path = os.path.join(
            self.unit_directory, InstallMagnetometerService.LEGACY_UNIT)
        os.makedirs(self.unit_directory)
        with open(legacy_path, mode='w', encoding='utf-8') as legacy_unit:
            legacy_unit.write('old unit')
        runner = RecordingSystemctl()

        InstallMagnetometerService.install_service(
            self.template_path, self.unit_directory, runner=runner)

        self.assertFalse(os.path.exists(legacy_path))
        self.assertLess(
            runner.commands.index(['systemctl', 'stop', 'PicoMagnetometerACM0.service']),
            runner.commands.index(['systemctl', 'disable', 'PicoMagnetometerACM0.service']))
        self.assertTrue(os.path.isfile(os.path.join(
            self.unit_directory, InstallMagnetometerService.CURRENT_UNIT)))

    def test_repeat_install_stops_current_unit_before_replacing_it(self):
        runner = RecordingSystemctl()
        InstallMagnetometerService.install_service(
            self.template_path, self.unit_directory, runner=runner)
        runner.commands.clear()

        InstallMagnetometerService.install_service(
            self.template_path, self.unit_directory, runner=runner)

        self.assertEqual(
            runner.commands[0], ['systemctl', 'stop', 'PicoMagnetometer.service'])

    def test_failure_stopping_legacy_unit_aborts_migration(self):
        os.makedirs(self.unit_directory)
        legacy_path = os.path.join(
            self.unit_directory, InstallMagnetometerService.LEGACY_UNIT)
        with open(legacy_path, mode='w', encoding='utf-8') as legacy_unit:
            legacy_unit.write('old unit')
        runner = RecordingSystemctl(
            ['systemctl', 'stop', 'PicoMagnetometerACM0.service'])

        with self.assertRaises(subprocess.CalledProcessError):
            InstallMagnetometerService.install_service(
                self.template_path, self.unit_directory, runner=runner)

        self.assertTrue(os.path.exists(legacy_path))
        self.assertFalse(os.path.exists(os.path.join(
            self.unit_directory, InstallMagnetometerService.CURRENT_UNIT)))


if __name__ == '__main__':
    unittest.main()