#!/usr/bin/env python3

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