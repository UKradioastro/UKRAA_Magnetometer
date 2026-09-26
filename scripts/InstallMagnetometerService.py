#!/usr/bin/env python3

import argparse
import os
import shutil
import subprocess


LEGACY_UNIT = 'PicoMagnetometerACM0.service'
CURRENT_UNIT = 'PicoMagnetometer.service'


def install_service(template_path, unit_directory, systemctl='systemctl', runner=None):
    if runner is None:
        runner = subprocess.run
    if not os.path.isfile(template_path):
        raise FileNotFoundError(f'Service template not found: {template_path}')

    os.makedirs(unit_directory, exist_ok=True)
    legacy_path = os.path.join(unit_directory, LEGACY_UNIT)
    current_path = os.path.join(unit_directory, CURRENT_UNIT)

    if os.path.exists(legacy_path):
        runner([systemctl, 'stop', LEGACY_UNIT], check=True)
        runner([systemctl, 'disable', LEGACY_UNIT], check=True)
        os.remove(legacy_path)

    if os.path.exists(current_path):
        runner([systemctl, 'stop', CURRENT_UNIT], check=True)

    shutil.copyfile(template_path, current_path)
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
    arguments = argument_parser.parse_args()

    install_service(
        arguments.template_path,
        arguments.unit_directory,
        arguments.systemctl)
    print(f'{CURRENT_UNIT} installed, enabled, and active')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())