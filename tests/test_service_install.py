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
            template.write('[Service]\nUser=@MAGNETOMETER_USER@\n'
                           'ExecStart=/usr/bin/python3 '
                           '@MAGNETOMETER_BASE_PATH@/scripts/GetDataRaw.py\n')

    def install_service(self, runner):
        InstallMagnetometerService.install_service(
            self.template_path, self.unit_directory, runner=runner,
            account='maguser', base_path='/home/maguser/UKRAA_Magnetometer')

    def tearDown(self):
        self.temporary_directory.cleanup()

    def test_fresh_install_installs_enables_and_verifies_new_unit(self):
        runner = RecordingSystemctl()

        self.install_service(runner)

        current_path = os.path.join(
            self.unit_directory, InstallMagnetometerService.CURRENT_UNIT)
        self.assertTrue(os.path.isfile(current_path))
        with open(current_path, mode='r', encoding='utf-8') as unit_file:
            unit_text = unit_file.read()
        self.assertIn('User=maguser', unit_text)
        self.assertIn('/home/maguser/UKRAA_Magnetometer/scripts/GetDataRaw.py', unit_text)
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

        self.install_service(runner)

        self.assertFalse(os.path.exists(legacy_path))
        self.assertLess(
            runner.commands.index(['systemctl', 'stop', 'PicoMagnetometerACM0.service']),
            runner.commands.index(['systemctl', 'disable', 'PicoMagnetometerACM0.service']))
        self.assertTrue(os.path.isfile(os.path.join(
            self.unit_directory, InstallMagnetometerService.CURRENT_UNIT)))

    def test_repeat_install_stops_current_unit_before_replacing_it(self):
        runner = RecordingSystemctl()
        self.install_service(runner)
        runner.commands.clear()

        self.install_service(runner)

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
            self.install_service(runner)

        self.assertTrue(os.path.exists(legacy_path))
        self.assertFalse(os.path.exists(os.path.join(
            self.unit_directory, InstallMagnetometerService.CURRENT_UNIT)))

    def test_cron_template_renders_non_pi_home_without_placeholders(self):
        template_path = os.path.join(
            os.path.dirname(__file__), '..', 'install', 'crontabMagnetometer.cron')
        with open(template_path, mode='r', encoding='utf-8') as template:
            cron_text = template.read()

        rendered = cron_text.replace(
            '@MAGNETOMETER_BASE_PATH@', '/srv/maguser/UKRAA_Magnetometer')
        self.assertNotIn('@MAGNETOMETER_BASE_PATH@', rendered)
        self.assertNotIn('/home/pi/', rendered)
        self.assertIn('/srv/maguser/UKRAA_Magnetometer/scripts/runCronJob.sh', rendered)
        self.assertEqual(rendered.count('/srv/maguser/UKRAA_Magnetometer/scripts/runCronJob.sh'), 8)

    def test_requires_account_and_base_path(self):
        with self.assertRaises(ValueError):
            InstallMagnetometerService.install_service(
                self.template_path, self.unit_directory, runner=RecordingSystemctl())


if __name__ == '__main__':
    unittest.main()