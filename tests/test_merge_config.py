import os
import sys
import tempfile
import unittest


SCRIPTS_PATH = os.path.join(os.path.dirname(__file__), '..', 'scripts')
sys.path.insert(0, os.path.abspath(SCRIPTS_PATH))

import MergeConfig


class MergeConfigTests(unittest.TestCase):
    def test_adds_missing_options_without_replacing_existing_values(self):
        template_text = '[plots]\nplot_hdz = false\nplot_kp = false\n'
        config_text = '# Site setting\n[plots]\nplot_hdz = true\n'

        additions, result = self._merge(template_text, config_text)

        self.assertEqual(additions, ['plots.plot_kp'])
        self.assertIn('# Site setting', result)
        self.assertIn('plot_hdz = true', result)
        self.assertIn('plot_kp = false', result)

    def test_adds_missing_section(self):
        additions, result = self._merge(
            '[alerts]\nenabled = false\n\n[heartbeat]\nhour_utc = 9\n',
            '[alerts]\nenabled = true\n')

        self.assertEqual(additions, ['heartbeat.hour_utc'])
        self.assertIn('[heartbeat]\nhour_utc = 9', result)

    def test_complete_configuration_is_unchanged(self):
        config_text = '[plots]\nplot_hdz = true\n'

        additions, result = self._merge(config_text, config_text)

        self.assertEqual(additions, [])
        self.assertEqual(result, config_text)

    def test_set_config_values_preserves_other_values_and_comments(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            config_path = os.path.join(temporary_directory, 'config.ini')
            config_text = (
                '# Keep this note\n'
                '[usb]\n'
                'serial_port = /dev/ttyACM0\n'
                'id_serial_short = old-id\n'
                'manual_option = keep-me\n')
            with open(config_path, mode='w', encoding='UTF-8') as config_file:
                config_file.write(config_text)

            changed = MergeConfig.set_config_values(
                config_path,
                'usb',
                {
                    'serial_port': '/dev/serial/by-id/pico-if00',
                    'id_serial': 'Raspberry_Pi_Pico_new-id',
                    'id_serial_short': 'new-id',
                })

            with open(config_path, mode='r', encoding='UTF-8') as config_file:
                result = config_file.read()

        self.assertTrue(changed)
        self.assertIn('# Keep this note', result)
        self.assertIn('manual_option = keep-me', result)
        self.assertIn('serial_port = /dev/serial/by-id/pico-if00', result)
        self.assertIn('id_serial = Raspberry_Pi_Pico_new-id', result)
        self.assertIn('id_serial_short = new-id', result)

    def _merge(self, template_text, config_text):
        with tempfile.TemporaryDirectory() as temporary_directory:
            template_path = os.path.join(temporary_directory, 'template.ini')
            config_path = os.path.join(temporary_directory, 'config.ini')
            with open(template_path, mode='w', encoding='UTF-8') as template_file:
                template_file.write(template_text)
            with open(config_path, mode='w', encoding='UTF-8') as config_file:
                config_file.write(config_text)

            additions = MergeConfig.merge_missing_options(
                template_path, config_path)
            with open(config_path, mode='r', encoding='UTF-8') as config_file:
                return additions, config_file.read()


if __name__ == '__main__':
    unittest.main()