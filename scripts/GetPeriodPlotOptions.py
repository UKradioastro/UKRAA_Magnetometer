#!/usr/bin/env python3

import json

from magnetometer_common import get_base_path
from magnetometer_common import get_period_plot_options


def main():
    print(json.dumps(get_period_plot_options(get_base_path()), sort_keys=True))


if __name__ == '__main__':
    main()