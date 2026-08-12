#!/usr/bin/env python3

from magnetometer_common import get_base_path
from magnetometer_common import get_plot_options


def main():
    plot_hdz, plot_bi = get_plot_options(get_base_path())
    print(f"{'true' if plot_hdz else 'false'} {'true' if plot_bi else 'false'}")


if __name__ == '__main__':
    main()
