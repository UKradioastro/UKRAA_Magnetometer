#!/usr/bin/env python3

import configparser
import csv
import datetime
import math
import os
import subprocess
import sys


RAW_FIELD_NAMES = [
    'RawDateTime',
    'RawX_V',
    'RawX_nT',
    'RawY_V',
    'RawY_nT',
    'RawZ_V',
    'RawZ_nT',
    'RawTMP36_degC',
    'RawDelta_nT',
    'RawColour',
    'RawDetectorName',
]

# Every logged Pico row with both values gives exactly 50,000 nT per volt; the
# earliest 8-column rows recorded volts only, so nT is rebuilt from this.
RAW_NT_PER_VOLT = 50000.0


def _is_number(text):
    try:
        float(text)
    except (TypeError, ValueError):
        return False
    return True


def parse_raw_row(row):
    """Return one raw CSV row as a RAW_FIELD_NAMES dict, or None if unusable.

    Supported layouts (datetime first, detector name last):
      8  : X_V, Y_V, Z_V, TMP36, temperature, pressure
      11 : X_V, X_nT, Y_V, Y_nT, Z_V, Z_nT, TMP36, Delta_nT, Colour (current)
      11 : X_V, X_nT, Y_V, Y_nT, Z_V, Z_nT, TMP36, temperature, pressure
      12 : X_V, X_nT, Y_V, Y_nT, Z_V, Z_nT, TMP36, temperature, pressure, Delta_nT
      13 : X_V, X_nT, Y_V, Y_nT, Z_V, Z_nT, TMP36, temperature, pressure, Delta_nT, Colour
    Layouts without Delta_nT report it as NaN.
    """
    row = [field.strip() for field in row]
    count = len(row)
    try:
        timestamp = parse_raw_datetime(row[0])
        if count == 8:
            x_v, y_v, z_v = (float(value) for value in row[1:4])
            values = [x_v, x_v * RAW_NT_PER_VOLT, y_v, y_v * RAW_NT_PER_VOLT,
                      z_v, z_v * RAW_NT_PER_VOLT, float(row[4]), math.nan]
            colour = ''
        elif count == 11 and not _is_number(row[9]):
            values = [float(value) for value in row[1:9]]
            colour = row[9]
        elif count == 11:
            values = [float(value) for value in row[1:8]] + [math.nan]
            colour = ''
        elif count in (12, 13):
            values = [float(value) for value in row[1:8]] + [float(row[10])]
            colour = row[11] if count == 13 else ''
        else:
            return None
    except (IndexError, TypeError, ValueError):
        return None

    parsed = {'RawDateTime': timestamp}
    parsed.update(zip(RAW_FIELD_NAMES[1:9], values))
    parsed['RawColour'] = colour
    parsed['RawDetectorName'] = row[-1]
    return parsed


def read_raw_rows(raw_data_file):
    """Yield parsed raw rows, skipping lines in an unrecognised layout."""
    with open(file=raw_data_file, mode='r', encoding='UTF-8', errors='replace') as raw_file:
        for row in csv.reader(raw_file):
            parsed = parse_raw_row(row)
            if parsed is not None:
                yield parsed


def format_fixed(value, decimal_places):
    if math.isnan(value):
        return 'nan'

    return format(value, f'.{decimal_places}f')


def get_target_date(default_days_ago=1):
    target_date = os.environ.get('MAGNETOMETER_TARGET_DATE')
    if target_date:
        try:
            return datetime.datetime.strptime(target_date, '%Y-%m-%d').date()
        except ValueError:
            raise ValueError(
                "MAGNETOMETER_TARGET_DATE '{}' is not a YYYY-MM-DD date".format(
                    target_date)) from None

    return (datetime.datetime.now() - datetime.timedelta(default_days_ago)).date()


def get_base_path():
    return os.environ.get(
        'MAGNETOMETER_BASE_PATH', os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def get_version(base_path):
    version_path = os.path.join(base_path, 'VERSION')
    try:
        with open(version_path, mode='r', encoding='UTF-8') as version_file:
            return version_file.read().strip()
    except OSError:
        return 'unknown'


def build_day_path(base_path, folder_name, target_date):
    return os.path.join(
        base_path,
        'data',
        folder_name,
        target_date.strftime('%Y'),
        target_date.strftime('%Y-%m'),
        target_date.strftime('%Y-%m-%d') + '.csv')


def build_month_path(base_path, folder_name, target_date):
    return os.path.join(
        base_path,
        'data',
        folder_name,
        target_date.strftime('%Y'),
        target_date.strftime('%Y-%m'))


def ensure_directory(path):
    os.makedirs(path, exist_ok=True)


def parse_raw_datetime(raw_datetime):
    return datetime.datetime.strptime(raw_datetime, '%Y-%m-%d %H:%M:%S')


def calculate_hdzbi(x_nt, y_nt, z_nt):
    calc_h = math.nan
    calc_d = math.nan
    calc_z = math.nan
    calc_b = math.nan
    calc_i = math.nan

    if not (math.isnan(x_nt) or math.isnan(y_nt)):
        calc_h = math.sqrt((x_nt * x_nt) + (y_nt * y_nt))
        if calc_h != 0:
            calc_d = math.degrees(math.atan2(y_nt, x_nt))
        if not math.isnan(z_nt):
            calc_z = z_nt

    if not (math.isnan(x_nt) or math.isnan(y_nt) or math.isnan(z_nt)):
        calc_b = math.sqrt((x_nt * x_nt) + (y_nt * y_nt) + (z_nt * z_nt))
        if (calc_b != 0) and (not math.isnan(calc_h)) and (calc_h != 0):
            calc_i = math.degrees(math.atan2(calc_z, calc_h))

    return calc_h, calc_d, calc_z, calc_b, calc_i


def utc_now():
    return datetime.datetime.now(datetime.timezone.utc)


def format_log_entry(timestamp, source_name, message):
    return (
        f'{timestamp:%Y-%m-%d %H:%M:%S} : '
        f'{source_name:<27} : {message}')


def log_message(source_name, message):
    print(format_log_entry(datetime.datetime.now(), source_name, message))


def log_error(source_name, message):
    print(format_log_entry(datetime.datetime.now(), source_name, message),
          file=sys.stderr, flush=True)


def _log_uncaught_exception(exc_type, exc_value, exc_traceback):
    # Python tracebacks carry no timestamp; prefix one so log-error.txt shows when it happened
    script_name = os.path.basename(sys.argv[0]) if sys.argv and sys.argv[0] else 'python'
    log_error(script_name, 'ERROR - unhandled {}: {}'.format(exc_type.__name__, exc_value))
    sys.__excepthook__(exc_type, exc_value, exc_traceback)


sys.excepthook = _log_uncaught_exception


def build_raw_day_path(base_path, current_time):
    return os.path.join(
        base_path,
        'data',
        'raw',
        current_time.strftime('%Y'),
        current_time.strftime('%Y-%m'),
        current_time.strftime('%Y-%m-%d') + '.csv')


def build_raw_month_path(base_path, current_time):
    return os.path.join(
        base_path,
        'data',
        'raw',
        current_time.strftime('%Y'),
        current_time.strftime('%Y-%m'))


def build_alerts_ini_path(base_path):
    configured_path = os.environ.get('MAGNETOMETER_ALERTS_INI_PATH', '').strip()
    if configured_path:
        return configured_path

    return os.path.join(base_path, 'config', 'alerts.ini')


def build_plot_ini_path(base_path):
    configured_path = os.environ.get('MAGNETOMETER_PLOT_INI_PATH', '').strip()
    if configured_path:
        return configured_path

    return os.path.join(base_path, 'config', 'plot.ini')


def build_usb_ini_path(base_path):
    configured_path = os.environ.get('MAGNETOMETER_USB_INI_PATH', '').strip()
    if configured_path:
        return configured_path

    return os.path.join(base_path, 'config', 'USB.ini')


def get_usb_options(base_path):
    parser = _load_ini_parser(build_usb_ini_path(base_path))

    return {
        'serial_port': parser.get('usb', 'serial_port', fallback='/dev/ttyACM0').strip()
            or '/dev/ttyACM0',
        'id_serial': parser.get('usb', 'id_serial', fallback='').strip(),
        'id_serial_short': parser.get('usb', 'id_serial_short', fallback='').strip(),
    }


def get_usb_identity(device_path):
    try:
        result = subprocess.run(
            ['udevadm', 'info', '--query=property', '--name=' + device_path],
            check=True, capture_output=True, text=True)
    except (OSError, subprocess.CalledProcessError) as exc:
        raise RuntimeError(
            f'Unable to read USB identity for {device_path}: {exc}') from exc

    return dict(
        line.split('=', 1)
        for line in result.stdout.splitlines()
        if '=' in line)


def verify_usb_identity(device_path, usb_options):
    expected_values = (
        ('ID_SERIAL', usb_options.get('id_serial', '')),
        ('ID_SERIAL_SHORT', usb_options.get('id_serial_short', '')),
    )
    if not any(expected_value for _, expected_value in expected_values):
        return {}

    actual_values = get_usb_identity(device_path)
    for property_name, expected_value in expected_values:
        if expected_value and actual_values.get(property_name) != expected_value:
            actual_value = actual_values.get(property_name, '<missing>')
            raise RuntimeError(
                f'USB identity mismatch for {device_path}: expected '
                f'{property_name}={expected_value}, got {actual_value}')

    return actual_values


def _parse_bool(value_text, default_value):
    if value_text is None:
        return default_value

    return value_text.strip().lower() in ('true', '1', 'yes')


def _parse_hemisphere(value_text, default_value):
    if value_text is None:
        return default_value

    normalized = value_text.strip().lower()
    if normalized in ('n', 'north', 'northern'):
        return 'north'
    if normalized in ('s', 'south', 'southern'):
        return 'south'

    return default_value


def get_plot_options(base_path):
    plot_ini_path = build_plot_ini_path(base_path)
    parser = _load_ini_parser(plot_ini_path)

    plot_hdz = _parse_bool(
        os.environ.get('MAGNETOMETER_PLOT_HDZ',
                       parser.get('plots', 'plot_hdz', fallback='true')),
        True)
    plot_bi = _parse_bool(
        os.environ.get('MAGNETOMETER_PLOT_BI',
                       parser.get('plots', 'plot_bi', fallback='true')),
        True)
    plot_noaa = _parse_bool(
        os.environ.get('MAGNETOMETER_PLOT_NOAA',
                       parser.get('plots', 'plot_noaa', fallback='true')),
        True)
    noaa_hemisphere = _parse_hemisphere(
        os.environ.get('MAGNETOMETER_NOAA_HEMISPHERE',
                       parser.get('plots', 'noaa_hemisphere', fallback='north')),
        'north')

    return plot_hdz, plot_bi, plot_noaa, noaa_hemisphere


def get_noaa_options(base_path):
    plot_hdz, plot_bi, plot_noaa, noaa_hemisphere = get_plot_options(base_path)
    return plot_noaa, noaa_hemisphere


def get_kp_options(base_path):
    plot_ini_path = build_plot_ini_path(base_path)
    parser = _load_ini_parser(plot_ini_path)

    return _parse_bool(
        os.environ.get('MAGNETOMETER_PLOT_KP',
                       parser.get('plots', 'plot_kp', fallback='true')),
        True)


def get_period_plot_options(base_path):
    plot_ini_path = build_plot_ini_path(base_path)
    parser = _load_ini_parser(plot_ini_path)
    period_names = ('week', 'month', '3month', '6month', 'year')

    return {
        period_name: _parse_bool(
            os.environ.get(
                'MAGNETOMETER_PLOT_' + period_name.upper(),
                parser.get('plots', 'plot_' + period_name, fallback='false')),
            False)
        for period_name in period_names
    }


def get_period_spaceweather_option(base_path):
    plot_ini_path = build_plot_ini_path(base_path)
    parser = _load_ini_parser(plot_ini_path)
    return _parse_bool(
        os.environ.get(
            'MAGNETOMETER_PLOT_PERIOD_SPACEWEATHER',
            parser.get('plots', 'plot_period_spaceweather', fallback='false')),
        False)


DEFAULT_PERIOD_MIN_VALID_DAYS_PERCENT = 90.0


def get_period_min_valid_days_percent(base_path):
    parser = _load_ini_parser(build_plot_ini_path(base_path))
    value_text = os.environ.get(
        'MAGNETOMETER_PERIOD_MIN_VALID_DAYS_PERCENT',
        parser.get('plots', 'period_min_valid_days_percent',
                   fallback=str(DEFAULT_PERIOD_MIN_VALID_DAYS_PERCENT)))
    percent = _parse_threshold(value_text, DEFAULT_PERIOD_MIN_VALID_DAYS_PERCENT)
    if not 0 < percent <= 100:
        return DEFAULT_PERIOD_MIN_VALID_DAYS_PERCENT
    return percent


def _load_ini_parser(config_path):
    parser = configparser.ConfigParser()
    if not os.path.exists(config_path):
        return parser

    with open(config_path, mode='r', encoding='UTF-8') as config_file:
        config_text = config_file.read().lstrip('\ufeff')
        parser.read_string(config_text)

    return parser


def _parse_threshold(value_text, default_value):
    try:
        return float(value_text)
    except (TypeError, ValueError):
        return float(default_value)


def get_alert_thresholds(base_path):
    alerts_ini_path = build_alerts_ini_path(base_path)
    parser = _load_ini_parser(alerts_ini_path)

    yellow_default = '50'
    amber_default = '100'
    red_default = '200'

    yellow_text = os.environ.get(
        'MAGNETOMETER_ALERT_YELLOW_NT',
        parser.get('alerts', 'yellow_threshold_nt', fallback=yellow_default))
    amber_text = os.environ.get(
        'MAGNETOMETER_ALERT_AMBER_NT',
        parser.get('alerts', 'amber_threshold_nt', fallback=amber_default))
    red_text = os.environ.get(
        'MAGNETOMETER_ALERT_RED_NT',
        parser.get('alerts', 'red_threshold_nt', fallback=red_default))

    return (
        _parse_threshold(yellow_text, yellow_default),
        _parse_threshold(amber_text, amber_default),
        _parse_threshold(red_text, red_default),
    )