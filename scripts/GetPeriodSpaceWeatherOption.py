#!/usr/bin/env python3

from magnetometer_common import get_base_path
from magnetometer_common import get_period_spaceweather_option


def main():
    print(str(get_period_spaceweather_option(get_base_path())).lower())


if __name__ == '__main__':
    main()