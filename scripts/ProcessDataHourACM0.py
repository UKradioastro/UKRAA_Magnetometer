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
        'ProcessDataHourACM0.py  :',
        message)

def create_empty_hour_bins(total_hours):
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
        for _ in range(total_hours)
    ]


def mean_or_nan(values):
    if values:
        return statistics.mean(values)

    return math.nan


def max_or_nan(values):
    if values:
        return max(values)

    return math.nan
def load_hour_bins(raw_data_file, raw_field_names, target_date):
    hour_bins = create_empty_hour_bins(24)
    detector_name = ''

    with open(file=raw_data_file, mode='r', encoding='UTF-8') as raw_file:
        raw_csv_reader = csv.DictReader(raw_file, raw_field_names)

        for raw_line in raw_csv_reader:
            raw_datetime = parse_raw_datetime(raw_line['RawDateTime'])

            if raw_datetime.date() != target_date:
                continue

            hour_bin = hour_bins[raw_datetime.hour]

            hour_bin['x_v'].append(float(raw_line['RawX_V']))
            hour_bin['x_nt'].append(float(raw_line['RawX_nT']))
            hour_bin['y_v'].append(float(raw_line['RawY_V']))
            hour_bin['y_nt'].append(float(raw_line['RawY_nT']))
            hour_bin['z_v'].append(float(raw_line['RawZ_V']))
            hour_bin['z_nt'].append(float(raw_line['RawZ_nT']))
            hour_bin['tmp36_degc'].append(float(raw_line['RawTMP36_degC']))
            hour_bin['delta_nt'].append(float(raw_line['RawDelta_nT']))

            detector_name = str(raw_line['RawDetectorName'])

    return hour_bins, detector_name

# print message to log file to say started

TargetDate = get_target_date()
BasePath = get_base_path()

log_msg('Started processing yesterdays hourly magnetometer data for ' \
      + TargetDate.strftime('%Y-%m-%d'))

# Set file headers for data file structure
RawFieldNames = RAW_FIELD_NAMES

# Set path for data file structure

# raw data file source
RawDataFile = build_day_path(BasePath, 'raw', TargetDate)


# Processed data path
ProcessedPath = build_month_path(BasePath, os.path.join('processed', 'hour'), TargetDate)

# check if the specific path exists
pathExists = os.path.exists(ProcessedPath)
if not pathExists:
    # create directory structure
    ensure_directory(ProcessedPath)
    log_msg('New directory created   : ' + ProcessedPath)

# Processed data file name
ProcessedDataFile = build_day_path(BasePath, os.path.join('processed', 'hour'), TargetDate)

# =============================================================================
# Main program

StartTime_str = TargetDate.strftime('%Y-%m-%d') + ' 00:00:00'

StartTime_datetime = datetime.datetime.strptime(StartTime_str, '%Y-%m-%d %H:%M:%S')
# uncomment next lines to print the response
#print('ProcessDataRawACM0.py: Value of variable (StartTime_datetime): ',StartTime_datetime)

EndTime_str = TargetDate.strftime('%Y-%m-%d') + ' 23:59:59'

EndTime_datetime = datetime.datetime.strptime(EndTime_str, '%Y-%m-%d %H:%M:%S')
# uncomment next lines to print the response
#print('ProcessDataRawACM0.py: Value of variable (EndTime_datetime): ',EndTime_datetime)

# define what the time change will be
minute = datetime.timedelta(
    days         =  0,
    seconds      =  0,
    microseconds =  0,
    milliseconds =  0,
    minutes      =  0,
    hours        =  1,
    weeks        =  0)
# uncomment next lines to print the response
#print('ProcessDataRawACM0.py: Value of variable (minute): ', minute)

# set up variable to use in loop
ProcessedTime = StartTime_datetime - minute

# number of 60 minutes in a day
n = 24

HourBins, DetectorName = load_hour_bins(RawDataFile, RawFieldNames, TargetDate)

delta = datetime.timedelta(minutes=30)

# open file to store data in and replace existing content
with open(file=ProcessedDataFile, mode='w', encoding='UTF-8') as ProcessedData:
    for i in range(1, n+1):
        # add an hour to each time value from 00:00:00 to 23:00:00
        ProcessedTime = ProcessedTime + minute

        hour_bin = HourBins[i - 1]

        Median_X_V = mean_or_nan(hour_bin['x_v'])
        Median_X_nT = mean_or_nan(hour_bin['x_nt'])
        Median_Y_V = mean_or_nan(hour_bin['y_v'])
        Median_Y_nT = mean_or_nan(hour_bin['y_nt'])
        Median_Z_V = mean_or_nan(hour_bin['z_v'])
        Median_Z_nT = mean_or_nan(hour_bin['z_nt'])
        Median_TMP36_degC = mean_or_nan(hour_bin['tmp36_degc'])
        Median_Delta_nT = max_or_nan(hour_bin['delta_nt'])

        Calc_H, Calc_D, Calc_Z, Calc_B, Calc_I = calculate_hdzbi(
            Median_X_nT,
            Median_Y_nT,
            Median_Z_nT)

        FileTime = ProcessedTime + delta

        # write processed data to file
        ProcessedData.write(str(FileTime))                      # Data time date
        ProcessedData.write(",")                               # "," separator
        ProcessedData.write(format_fixed(Median_X_V, 6))       # 1 hour average X(V)
        ProcessedData.write(",")                               # "," separator
        ProcessedData.write(format_fixed(Median_Y_V, 6))       # 1 hour average Y(V)
        ProcessedData.write(",")                               # "," separator
        ProcessedData.write(format_fixed(Median_Z_V, 6))       # 1 hour average Z(V)
        ProcessedData.write(",")                               # "," separator
        ProcessedData.write(format_fixed(Median_X_nT, 0))      # 1 hour average X(nT)
        ProcessedData.write(",")                               # "," separator
        ProcessedData.write(format_fixed(Median_Y_nT, 0))      # 1 hour average Y(nT)
        ProcessedData.write(",")                               # "," separator
        ProcessedData.write(format_fixed(Median_Z_nT, 0))      # 1 hour average Z(nT)
        ProcessedData.write(",")                               # "," separator
        ProcessedData.write(format_fixed(Median_TMP36_degC, 1))# 1 hour average TMP36 temperature
        ProcessedData.write(",")                               # "," separator
        ProcessedData.write(format_fixed(Median_Delta_nT, 1))  # 1 hour max Delta(nT)
        ProcessedData.write(",")                               # "," separator
        ProcessedData.write(format_fixed(Calc_H, 0))           # Calculated H value
        ProcessedData.write(",")                               # "," separator
        ProcessedData.write(format_fixed(Calc_D, 1))           # Calculated D value
        ProcessedData.write(",")                               # "," separator
        ProcessedData.write(format_fixed(Calc_Z, 0))           # Calculated Z value
        ProcessedData.write(",")                               # "," separator
        ProcessedData.write(format_fixed(Calc_B, 0))           # Calculated B value
        ProcessedData.write(",")                               # "," separator
        ProcessedData.write(format_fixed(Calc_I, 1))           # Calculated I value
        ProcessedData.write(",")                               # "," separator
        ProcessedData.write(DetectorName)                      # Detector name
        ProcessedData.write("\n")                              # new line

# =============================================================================
# Message to log file at end of program

# print message to log file to say completed
log_msg('Completed processing yesterdays hourly magnetometer data for ' \
    + TargetDate.strftime('%Y-%m-%d'))
      

# =============================================================================
# END of program