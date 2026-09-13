#!/usr/bin/env python3

import configparser
import datetime
import math
import os


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


def format_fixed(value, decimal_places):
    if math.isnan(value):
        return 'nan'

    return format(value, f'.{decimal_places}f')


def get_target_date(default_days_ago=1):
    target_date = os.environ.get('MAGNETOMETER_TARGET_DATE')
    if target_date:
        return datetime.datetime.strptime(target_date, '%Y-%m-%d').date()

    return (datetime.datetime.now() - datetime.timedelta(default_days_ago)).date()


def get_base_path():
    return os.environ.get('MAGNETOMETER_BASE_PATH', '/home/pi/UKRAA_Magnetometer')


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