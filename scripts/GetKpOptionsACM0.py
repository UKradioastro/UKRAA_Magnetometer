#!/usr/bin/env python3

from magnetometer_common import get_base_path, get_kp_options


def main():
    plot_kp = get_kp_options(get_base_path())
    print('true' if plot_kp else 'false')


if __name__ == '__main__':
    main()