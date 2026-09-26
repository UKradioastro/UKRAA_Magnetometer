#!/usr/bin/env python3

from magnetometer_common import get_alert_thresholds
from magnetometer_common import get_base_path


def main():
    yellow_threshold, amber_threshold, red_threshold = get_alert_thresholds(get_base_path())
    print(f"{yellow_threshold:g} {amber_threshold:g} {red_threshold:g}")


if __name__ == '__main__':
    main()
