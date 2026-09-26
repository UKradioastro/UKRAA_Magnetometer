#!/usr/bin/env python3

import glob
import os
import sys

from MergeConfig import set_config_values
from magnetometer_common import build_usb_ini_path
from magnetometer_common import get_base_path
from magnetometer_common import get_usb_identity


def find_by_id_alias(device_path):
    device_target = os.path.realpath(device_path)
    for alias_path in sorted(glob.glob('/dev/serial/by-id/*')):
        if os.path.realpath(alias_path) == device_target:
            return alias_path
    return ''


def configure_usb(device_path, config_path, serial_port=None):
    if not os.path.exists(device_path):
        raise ValueError(f'Device does not exist: {device_path}')

    identity = get_usb_identity(device_path)
    id_serial = identity.get('ID_SERIAL', '').strip()
    id_serial_short = identity.get('ID_SERIAL_SHORT', '').strip()
    if not id_serial and not id_serial_short:
        raise RuntimeError(
            f'No ID_SERIAL or ID_SERIAL_SHORT reported for {device_path}; '
            'USB.ini was not changed.')

    selected_port = serial_port or device_path
    if not os.path.exists(selected_port):
        raise ValueError(f'Selected serial path does not exist: {selected_port}')

    config_directory = os.path.dirname(config_path)
    os.makedirs(config_directory, exist_ok=True)
    if not os.path.exists(config_path):
        with open(config_path, mode='w', encoding='UTF-8') as config_file:
            config_file.write('[usb]\n')

    set_config_values(
        config_path,
        'usb',
        {
            'serial_port': selected_port,
            'id_serial': id_serial,
            'id_serial_short': id_serial_short,
        })
    return identity, selected_port


def main():
    device_path = input('Magnetometer device path [/dev/ttyACM0]: ').strip()
    if not device_path:
        device_path = '/dev/ttyACM0'

    selected_port = device_path
    by_id_alias = find_by_id_alias(device_path)
    if by_id_alias:
        print(f'Stable by-id path found: {by_id_alias}')
        use_alias = input('Use this path in USB.ini? [y/N]: ').strip().lower()
        if use_alias in ('y', 'yes'):
            selected_port = by_id_alias

    config_path = build_usb_ini_path(get_base_path())
    try:
        identity, selected_port = configure_usb(
            device_path, config_path, selected_port)
    except (OSError, RuntimeError, ValueError) as error:
        print(f'USB configuration failed: {error}', file=sys.stderr)
        return 1

    print(f'Updated {config_path}')
    print(f'serial_port = {selected_port}')
    print(f"id_serial = {identity.get('ID_SERIAL', '')}")
    print(f"id_serial_short = {identity.get('ID_SERIAL_SHORT', '')}")
    return 0


if __name__ == '__main__':
    raise SystemExit(main())