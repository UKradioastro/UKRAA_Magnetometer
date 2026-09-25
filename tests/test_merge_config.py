import os
import sys
import tempfile
import unittest


SCRIPTS_PATH = os.path.join(os.path.dirname(__file__), '..', 'scripts')
sys.path.insert(0, os.path.abspath(SCRIPTS_PATH))

import MergeConfigACM0


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

    def _merge(self, template_text, config_text):
        with tempfile.TemporaryDirectory() as temporary_directory:
            template_path = os.path.join(temporary_directory, 'template.ini')
            config_path = os.path.join(temporary_directory, 'config.ini')
            with open(template_path, mode='w', encoding='UTF-8') as template_file:
                template_file.write(template_text)
            with open(config_path, mode='w', encoding='UTF-8') as config_file:
                config_file.write(config_text)

            additions = MergeConfigACM0.merge_missing_options(
                template_path, config_path)
            with open(config_path, mode='r', encoding='UTF-8') as config_file:
                return additions, config_file.read()


if __name__ == '__main__':
    unittest.main()