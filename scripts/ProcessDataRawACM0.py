#!/usr/bin/env python3

#imports
import datetime
import csv
import os
import math
import statistics

from magnetometer_common import RAW_FIELD_NAMES
from magnetometer_common import build_day_path
from magnetometer_common import build_month_path
from magnetometer_common import calculate_hdzbi
from magnetometer_common import ensure_directory
from magnetometer_common import format_fixed
from magnetometer_common import get_base_path
from magnetometer_common import get_target_date
from magnetometer_common import parse_raw_datetime

# logfile message helper
def log_msg(message):
    print(datetime.datetime.strftime(datetime.datetime.now(), '%Y-%m-%d %H:%M:%S'),
        ':',
        'ProcessDataRawACM0.py     :',
        message)

def create_empty_minute_bins(total_minutes):
    return [
        {
            'x_v': [],
            'x_nt': [],
            'y_v': [],
            'y_nt': [],
            'z_v': [],
            'z_nt': [],
            'tmp36_degc': [],
            'delta_nt': [],
        }
        for _ in range(total_minutes)
    ]


def median_or_nan(values):
    if values:
        return statistics.median(values)

    return math.nan
def load_minute_bins(raw_data_file, raw_field_names, target_date):
    minute_bins = create_empty_minute_bins(1440)
    detector_name = ''

    with open(file=raw_data_file, mode='r', encoding='UTF-8') as raw_file:
        raw_csv_reader = csv.DictReader(raw_file, raw_field_names)

        for raw_line in raw_csv_reader:
            raw_datetime = parse_raw_datetime(raw_line['RawDateTime'])

            if raw_datetime.date() != target_date:
                continue

            minute_index = (raw_datetime.hour * 60) + raw_datetime.minute
            minute_bin = minute_bins[minute_index]

            minute_bin['x_v'].append(float(raw_line['RawX_V']))
            minute_bin['x_nt'].append(float(raw_line['RawX_nT']))
            minute_bin['y_v'].append(float(raw_line['RawY_V']))
            minute_bin['y_nt'].append(float(raw_line['RawY_nT']))
            minute_bin['z_v'].append(float(raw_line['RawZ_V']))
            minute_bin['z_nt'].append(float(raw_line['RawZ_nT']))
            minute_bin['tmp36_degc'].append(float(raw_line['RawTMP36_degC']))
            minute_bin['delta_nt'].append(float(raw_line['RawDelta_nT']))

            detector_name = str(raw_line['RawDetectorName'])

    return minute_bins, detector_name

# print message to log file to say started
TargetDate = get_target_date()
BasePath = get_base_path()

log_msg('Started processing yesterdays magnetometer data for ' \
      + TargetDate.strftime('%Y-%m-%d'))

# Set file headers for data file structure
RawFieldNames = RAW_FIELD_NAMES

# Set path for data file structure

# raw data file source
RawDataFile = build_day_path(BasePath, 'raw', TargetDate)


# Minute data path
MinutePath = build_month_path(BasePath, 'minute', TargetDate)

# check if the specific path exists
pathExists = os.path.exists(MinutePath)
if not pathExists:
    # create directory structure
    ensure_directory(MinutePath)
    log_msg('New directory created : ' + MinutePath)

# Minute data file name
ProcessedDataFile = build_day_path(BasePath, 'minute', TargetDate)

# =============================================================================
# Main program

StartTime_str = TargetDate.strftime('%Y-%m-%d') + ' 00:00:00'

StartTime_datetime = datetime.datetime.strptime(StartTime_str, '%Y-%m-%d %H:%M:%S')

EndTime_str = TargetDate.strftime('%Y-%m-%d') + ' 23:59:59'

EndTime_datetime = datetime.datetime.strptime(EndTime_str, '%Y-%m-%d %H:%M:%S')

# define what the time change will be
minute = datetime.timedelta(
    days         =  0,
    seconds      =  0,
    microseconds =  0,
    milliseconds =  0,
    minutes      =  1,
    hours        =  0,
    weeks        =  0)

# set up variable to use in loop
ProcessedTime = StartTime_datetime - minute

# number of 1 minutes in a day
n = 1440

MinuteBins, DetectorName = load_minute_bins(RawDataFile, RawFieldNames, TargetDate)

# open file to store data in and replace existing content
with open(file=ProcessedDataFile, mode='w', encoding='UTF-8') as ProcessedData:
    for i in range(1, n+1):
        # add a minute to each time value from 00:00:00 to 23:59:00
        ProcessedTime = ProcessedTime + minute

        minute_bin = MinuteBins[i - 1]

        Median_X_V = median_or_nan(minute_bin['x_v'])
        Median_X_nT = median_or_nan(minute_bin['x_nt'])
        Median_Y_V = median_or_nan(minute_bin['y_v'])
        Median_Y_nT = median_or_nan(minute_bin['y_nt'])
        Median_Z_V = median_or_nan(minute_bin['z_v'])
        Median_Z_nT = median_or_nan(minute_bin['z_nt'])
        Median_TMP36_degC = median_or_nan(minute_bin['tmp36_degc'])
        Median_Delta_nT = median_or_nan(minute_bin['delta_nt'])

        Calc_H, Calc_D, Calc_Z, Calc_B, Calc_I = calculate_hdzbi(
            Median_X_nT,
            Median_Y_nT,
            Median_Z_nT)

        # write processed data to file
        ProcessedData.write(str(ProcessedTime))                  # Data time date
        ProcessedData.write(",")                                 # "," separator
        ProcessedData.write(format_fixed(Median_X_V, 6))         # 1 minute average X(V)
        ProcessedData.write(",")                                 # "," separator
        ProcessedData.write(format_fixed(Median_Y_V, 6))         # 1 minute average Y(V)
        ProcessedData.write(",")                                 # "," separator
        ProcessedData.write(format_fixed(Median_Z_V, 6))         # 1 minute average Z(V)
        ProcessedData.write(",")                                 # "," separator
        ProcessedData.write(format_fixed(Median_X_nT, 0))        # 1 minute average X(nT)
        ProcessedData.write(",")                                 # "," separator
        ProcessedData.write(format_fixed(Median_Y_nT, 0))        # 1 minute average Y(nT)
        ProcessedData.write(",")                                 # "," separator
        ProcessedData.write(format_fixed(Median_Z_nT, 0))        # 1 minute average Z(nT)
        ProcessedData.write(",")                                 # "," separator
        ProcessedData.write(format_fixed(Median_TMP36_degC, 1))  # 1 minute average TMP36 temperature
        ProcessedData.write(",")                                 # "," separator
        ProcessedData.write(format_fixed(Median_Delta_nT, 1))    # 1 minute average Delta(nT)
        ProcessedData.write(",")                                 # "," separator
        ProcessedData.write(format_fixed(Calc_H, 0))             # Calculated H value
        ProcessedData.write(",")                                 # "," separator
        ProcessedData.write(format_fixed(Calc_D, 1))             # Calculated D value
        ProcessedData.write(",")                                 # "," separator
        ProcessedData.write(format_fixed(Calc_Z, 0))             # Calculated Z value
        ProcessedData.write(",")                                 # "," separator
        ProcessedData.write(format_fixed(Calc_B, 0))             # Calculated B value
        ProcessedData.write(",")                                 # "," separator
        ProcessedData.write(format_fixed(Calc_I, 1))             # Calculated I value
        ProcessedData.write(",")                                 # "," separator
        ProcessedData.write(DetectorName)                        # Detector name
        ProcessedData.write("\n")                                # new line

# =============================================================================
# Message to log file at end of program

# print message to log file to say completed
log_msg('Completed processing yesterdays magnetometer data for ' \
    + TargetDate.strftime('%Y-%m-%d'))
      

# =============================================================================
# END of program