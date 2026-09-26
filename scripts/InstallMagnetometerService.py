#!/usr/bin/env python3

import argparse
import os
import subprocess


LEGACY_UNIT = 'PicoMagnetometerACM0.service'
CURRENT_UNIT = 'PicoMagnetometer.service'


def install_service(template_path, unit_directory, systemctl='systemctl', runner=None,
                    account=None, base_path=None):
    if runner is None:
        runner = subprocess.run
    if not os.path.isfile(template_path):
        raise FileNotFoundError(f'Service template not found: {template_path}')
    if not account or not base_path:
        raise ValueError('Service account and base path are required')

    os.makedirs(unit_directory, exist_ok=True)
    legacy_path = os.path.join(unit_directory, LEGACY_UNIT)
    current_path = os.path.join(unit_directory, CURRENT_UNIT)

    if os.path.exists(legacy_path):
        runner([systemctl, 'stop', LEGACY_UNIT], check=True)
        runner([systemctl, 'disable', LEGACY_UNIT], check=True)
        os.remove(legacy_path)

    if os.path.exists(current_path):
        runner([systemctl, 'stop', CURRENT_UNIT], check=True)

    with open(template_path, mode='r', encoding='UTF-8') as template_file:
        unit_text = template_file.read()
    unit_text = unit_text.replace('@MAGNETOMETER_USER@', account)
    unit_text = unit_text.replace('@MAGNETOMETER_BASE_PATH@', base_path)
    with open(current_path, mode='w', encoding='UTF-8') as unit_file:
        unit_file.write(unit_text)
    os.chmod(current_path, 0o644)
    runner([systemctl, 'daemon-reload'], check=True)
    runner([systemctl, 'enable', '--now', CURRENT_UNIT], check=True)
    runner([systemctl, 'is-active', '--quiet', CURRENT_UNIT], check=True)
    runner([systemctl, 'is-enabled', '--quiet', CURRENT_UNIT], check=True)


def main():
    argument_parser = argparse.ArgumentParser(
        description='Install and activate the magnetometer collector service.')
    argument_parser.add_argument('template_path')
    argument_parser.add_argument(
        '--unit-directory', default='/etc/systemd/system')
    argument_parser.add_argument('--systemctl', default='systemctl')
    argument_parser.add_argument('--account', required=True)
    argument_parser.add_argument('--base-path', required=True)
    arguments = argument_parser.parse_args()

    install_service(
        arguments.template_path,
        arguments.unit_directory,
        arguments.systemctl,
        account=arguments.account,
        base_path=arguments.base_path)
    print(f'{CURRENT_UNIT} installed, enabled, and active')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())