#!/usr/bin/env python3

from magnetometer_common import get_base_path
from magnetometer_common import get_plot_options


def main():
    plot_hdz, plot_bi, plot_noaa, noaa_hemisphere = get_plot_options(get_base_path())
    print(f"{'true' if plot_hdz else 'false'} {'true' if plot_bi else 'false'} {'true' if plot_noaa else 'false'} {noaa_hemisphere}")


if __name__ == '__main__':
    main()
