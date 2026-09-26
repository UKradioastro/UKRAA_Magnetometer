import os
import sys
import tempfile
import unittest
from unittest.mock import patch


SCRIPTS_PATH = os.path.join(os.path.dirname(__file__), '..', 'scripts')
sys.path.insert(0, os.path.abspath(SCRIPTS_PATH))

import magnetometer_common
import ConfigureUSB


class UsbConfigTests(unittest.TestCase):
    def setUp(self):
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.base_path = self.temporary_directory.name
        self.config_directory = os.path.join(self.base_path, 'config')
        os.makedirs(self.config_directory)

    def tearDown(self):
        self.temporary_directory.cleanup()

    def test_missing_config_uses_default_port_and_empty_identity(self):
        self.assertEqual(
            magnetometer_common.get_usb_options(self.base_path),
            {
                'serial_port': '/dev/ttyACM0',
                'id_serial': '',
                'id_serial_short': '',
            })

    def test_reads_port_and_identity_from_config(self):
        config_path = os.path.join(self.config_directory, 'USB.ini')
        with open(config_path, mode='w', encoding='utf-8') as config_file:
            config_file.write(
                '[usb]\n'
                'serial_port = /dev/serial/by-id/pico-if00\n'
                'id_serial = Raspberry_Pi_Pico_1234\n'
                'id_serial_short = 1234\n')

        self.assertEqual(
            magnetometer_common.get_usb_options(self.base_path),
            {
                'serial_port': '/dev/serial/by-id/pico-if00',
                'id_serial': 'Raspberry_Pi_Pico_1234',
                'id_serial_short': '1234',
            })

    def test_parses_udev_properties(self):
        result = type('Result', (), {
            'stdout': 'ID_SERIAL=Raspberry_Pi_Pico_1234\nID_SERIAL_SHORT=1234\n'
        })()
        with patch('magnetometer_common.subprocess.run', return_value=result) as run:
            identity = magnetometer_common.get_usb_identity('/dev/ttyACM0')

        self.assertEqual(identity['ID_SERIAL_SHORT'], '1234')
        run.assert_called_once_with(
            ['udevadm', 'info', '--query=property', '--name=/dev/ttyACM0'],
            check=True, capture_output=True, text=True)

    def test_verifies_expected_identity(self):
        options = {
            'id_serial': 'Raspberry_Pi_Pico_1234',
            'id_serial_short': '1234',
        }
        identity = {
            'ID_SERIAL': 'Raspberry_Pi_Pico_1234',
            'ID_SERIAL_SHORT': '1234',
        }
        with patch('magnetometer_common.get_usb_identity', return_value=identity):
            self.assertEqual(
                magnetometer_common.verify_usb_identity('/dev/ttyACM0', options),
                identity)

    def test_rejects_mismatched_identity(self):
        options = {'id_serial_short': 'expected'}
        with patch(
                'magnetometer_common.get_usb_identity',
                return_value={'ID_SERIAL_SHORT': 'other'}):
            with self.assertRaisesRegex(RuntimeError, 'USB identity mismatch'):
                magnetometer_common.verify_usb_identity('/dev/ttyACM0', options)

    def test_skips_identity_query_when_no_expected_id_is_configured(self):
        with patch('magnetometer_common.get_usb_identity') as get_identity:
            self.assertEqual(
                magnetometer_common.verify_usb_identity(
                    '/dev/ttyACM0', {'id_serial': '', 'id_serial_short': ''}),
                {})
        get_identity.assert_not_called()

    def test_configurator_writes_identity_and_preserves_other_settings(self):
        device_path = os.path.join(self.base_path, 'ttyACM0')
        with open(device_path, mode='w', encoding='utf-8'):
            pass
        config_path = os.path.join(self.config_directory, 'USB.ini')
        with open(config_path, mode='w', encoding='utf-8') as config_file:
            config_file.write('# Site configuration\n[usb]\nmanual_option = keep\n')
        identity = {
            'ID_SERIAL': 'Raspberry_Pi_Pico_1234',
            'ID_SERIAL_SHORT': '1234',
        }

        with patch('ConfigureUSB.get_usb_identity', return_value=identity):
            saved_identity, selected_port = ConfigureUSB.configure_usb(
                device_path, config_path)

        with open(config_path, mode='r', encoding='utf-8') as config_file:
            result = config_file.read()
        self.assertEqual(saved_identity, identity)
        self.assertEqual(selected_port, device_path)
        self.assertIn('# Site configuration', result)
        self.assertIn('manual_option = keep', result)
        self.assertIn(f'serial_port = {device_path}', result)
        self.assertIn('id_serial = Raspberry_Pi_Pico_1234', result)
        self.assertIn('id_serial_short = 1234', result)

    def test_configurator_refuses_to_change_config_without_serial_identity(self):
        device_path = os.path.join(self.base_path, 'ttyACM0')
        with open(device_path, mode='w', encoding='utf-8'):
            pass
        config_path = os.path.join(self.config_directory, 'USB.ini')
        with open(config_path, mode='w', encoding='utf-8') as config_file:
            config_file.write('[usb]\nserial_port = /dev/ttyACM0\n')

        with patch('ConfigureUSB.get_usb_identity', return_value={}):
            with self.assertRaisesRegex(RuntimeError, 'No ID_SERIAL'):
                ConfigureUSB.configure_usb(device_path, config_path)

        with open(config_path, mode='r', encoding='utf-8') as config_file:
            self.assertEqual(
                config_file.read(), '[usb]\nserial_port = /dev/ttyACM0\n')


if __name__ == '__main__':
    unittest.main()