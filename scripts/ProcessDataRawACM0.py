#!/usr/bin/env python3

#imports
import datetime
import csv
import os
import math
import statistics

# print message to log file to say started

print('ProcessDataRawACM0.py :', \
      datetime.datetime.strftime(datetime.datetime.now(), '%Y-%m-%d %H:%M:%S'), \
      ': Started processing yesterdays magnetometer data for', \
      datetime.datetime.strftime(datetime.datetime.now() - datetime.timedelta(1), '%Y-%m-%d'))

# Set file headers for data file structure
RawFieldNames    = ['RawDateTime',\
                    'RawX_V', \
                    'RawX_nT', \
                    'RawY_V', \
                    'RawY_nT', \
                    'RawZ_V', \
                    'RawZ_nT', \
                    'RawTMP36_degC', \
                    'RawDelta_nT', \
                    'RawColour', \
                    'RawDetectorName']

# Set path for data file structure

# raw data file source
RawDataFile   = "/home/pi/UKRAA_Magnetometer/data/raw/" \
                 + datetime.datetime.strftime(datetime.datetime.now() - datetime.timedelta(1), '%Y') \
                 + "/" \
                 + datetime.datetime.strftime(datetime.datetime.now() - datetime.timedelta(1), '%Y-%m') \
                 + "/" \
                 + datetime.datetime.strftime(datetime.datetime.now() - datetime.timedelta(1), '%Y-%m-%d') \
                 + ".csv"


# Processed data path
ProcessedPath = '/home/pi/UKRAA_Magnetometer/data/processed/'\
                + datetime.datetime.strftime(datetime.datetime.now() - datetime.timedelta(1), '%Y') \
                + "/" \
                + datetime.datetime.strftime(datetime.datetime.now() - datetime.timedelta(1), '%Y-%m')

# check if the specific path exists
pathExists = os.path.exists(ProcessedPath)
if not pathExists:
    # create directory structure
    os.makedirs(ProcessedPath)
    print('ProcessDataRawACM0.py :', \
          datetime.datetime.strftime(datetime.datetime.now(), '%Y-%m-%d %H:%M:%S'), \
          ': New directory created :', \
          ProcessedPath)

# Processed data file name
ProcessedDataFile = "/home/pi/UKRAA_Magnetometer/data/processed/" \
                     + datetime.datetime.strftime(datetime.datetime.now() - datetime.timedelta(1), '%Y') \
                     + "/" \
                     + datetime.datetime.strftime(datetime.datetime.now() - datetime.timedelta(1), '%Y-%m') \
                     + "/" \
                     + datetime.datetime.strftime(datetime.datetime.now() - datetime.timedelta(1), '%Y-%m-%d') \
                     + ".csv"

# =============================================================================
# Main program

StartTime_str = datetime.datetime.strftime(datetime.datetime.now() - datetime.timedelta(1), '%Y-%m-%d') \
                + ' 00:00:00'

StartTime_datetime = datetime.datetime.strptime(StartTime_str, '%Y-%m-%d %H:%M:%S')
# uncomment next lines to print the response
#print('ProcessDataRawACM0.py: Value of variable (StartTime_datetime): ',StartTime_datetime)

EndTime_str = datetime.datetime.strftime(datetime.datetime.now() - datetime.timedelta(1), '%Y-%m-%d') \
              + ' 23:59:59'

EndTime_datetime = datetime.datetime.strptime(EndTime_str, '%Y-%m-%d %H:%M:%S')
# uncomment next lines to print the response
#print('ProcessDataRawACM0.py: Value of variable (EndTime_datetime): ',EndTime_datetime)

# define what the time change will be
minute = datetime.timedelta(
    days         =  0,
    seconds      =  0,
    microseconds =  0,
    milliseconds =  0,
    minutes      =  1,
    hours        =  0,
    weeks        =  0)
# uncomment next lines to print the response
#print('ProcessDataRawACM0.py: Value of variable (minute): ', minute)

# set up variable to use in loop
ProcessedTime = StartTime_datetime - minute

# number of 1 minutes in a day
n = 1440

# open file to store data in and append to end
ProcessedData = open(file=ProcessedDataFile, mode='a', encoding='UTF-8')

for i in range(1, n+1):
    # add a minute to each time value from 00:00:00 to 23:59:00
    ProcessedTime = ProcessedTime + minute
    
    StartBinTime = ProcessedTime

    EndBinTime = StartBinTime + minute

    # using csv.DictReader
    RawFile = open(file=RawDataFile, mode='r', encoding='UTF-8')
    RawCSV_reader = csv.DictReader(RawFile,RawFieldNames)

    # set counters to zero
    List_X_V          = list()
    List_Y_V          = list()
    List_Z_V          = list()
    List_X_nT         = list()
    List_Y_nT         = list()
    List_Z_nT         = list()
    List_TMP36_degC   = list()
    List_Delta_nT     = list()
    Median_X_V        = 0.000000
    Median_Y_V        = 0.000000
    Median_Z_V        = 0.000000
    Median_X_nT       = 0.0
    Median_Y_nT       = 0.0
    Median_Z_nT       = 0.0
    Median_TMP36_degC = 0.00
    Median_Delta_nT   = 0.00
    Calc_H            = 0.000000
    Calc_D            = 0.0000
    Calc_Z            = 0.000000
    Calc_B            = 0.000000
    Calc_I            = 0.0000
    

    for RawLine in RawCSV_reader:
        # try to get raw data after start StartBinTime
        # convert string to datetime.datetime format
        RawDatetime = datetime.datetime.strptime(RawLine['RawDateTime'], 
                                                 '%Y-%m-%d %H:%M:%S')
        
        # search file for data between two time points
        if (RawDatetime >= StartBinTime) and (RawDatetime < EndBinTime):
            List_X_V.append(float(RawLine['RawX_V']))
            List_X_nT.append(float(RawLine['RawX_nT']))
            List_Y_V.append(float(RawLine['RawY_V']))
            List_Y_nT.append(float(RawLine['RawY_nT']))
            List_Z_V.append(float(RawLine['RawZ_V']))
            List_Z_nT.append(float(RawLine['RawZ_nT']))
            List_TMP36_degC.append(float(RawLine['RawTMP36_degC']))
            List_Delta_nT.append(float(RawLine['RawDelta_nT']))
            
    # close open RawFile
    RawFile.close()

    
    # check if there is some x-axis data
    if (len(List_X_V) != 0):
        Median_X_V = statistics.median(List_X_V)
    else:
        Median_X_V = math.nan
        
    if (len(List_X_nT) != 0):
        Median_X_nT = statistics.median(List_X_nT)
    else:
        Median_X_nT = math.nan
        
    # check if there is some y-axis data
    if (len(List_Y_V) != 0):
        Median_Y_V = statistics.median(List_Y_V)
    else:
        Median_Y_V = math.nan
    
    if (len(List_Y_nT) != 0):
        Median_Y_nT = statistics.median(List_Y_nT)
    else:
        Median_Y_nT = math.nan
        
    # check if there is some z-axis data
    if (len(List_Z_V) != 0):
        Median_Z_V = statistics.median(List_Z_V)
    else:
        Median_Z_V = math.nan
        
    if (len(List_Z_nT) != 0):
        Median_Z_nT = statistics.median(List_Z_nT)
    else:
        Median_Z_nT = math.nan
        
    # check if there is some TMP36 temp data
    if (len(List_TMP36_degC) != 0):
        Median_TMP36_degC = statistics.median(List_TMP36_degC)
    else:
        Median_TMP36_degC = math.nan
        
    # check if there is some Delta_nT data
    if (len(List_Delta_nT) != 0):
        Median_Delta_nT = statistics.median(List_Delta_nT)
    else:
        Median_Delta_nT = math.nan


    # Process XYZ data to HDZ data
    Calc_H = math.nan
    Calc_D = math.nan
    Calc_Z = math.nan

    if not (math.isnan(Median_X_nT) or math.isnan(Median_Y_nT)):
        Calc_H = math.sqrt((Median_X_nT * Median_X_nT) + (Median_Y_nT * Median_Y_nT))
        if (Calc_H != 0):
            Calc_D = math.degrees(math.atan2(Median_Y_nT, Median_X_nT))
        if not math.isnan(Median_Z_nT):
            Calc_Z = Median_Z_nT

    # Process XYZ & HZ data to BI data
    Calc_B = math.nan
    Calc_I = math.nan
    if not (math.isnan(Median_X_nT) or math.isnan(Median_Y_nT) or math.isnan(Median_Z_nT)):
        Calc_B = math.sqrt((Median_X_nT * Median_X_nT) + (Median_Y_nT * Median_Y_nT) + (Median_Z_nT * Median_Z_nT))
        if (Calc_B != 0) and (not math.isnan(Calc_H)) and (Calc_H != 0):
            Calc_I = math.degrees(math.atan2(Calc_Z, Calc_H))


    # write processed data to file
    ProcessedData.write(str(ProcessedTime))                  # Data time date
    ProcessedData.write(",")                                 # "," separator
    ProcessedData.write(str(Median_X_V))                     # 1 minute average X(V)
    ProcessedData.write(",")                                 # "," separator
    ProcessedData.write(str(Median_Y_V))                     # 1 minute average Y(V)
    ProcessedData.write(",")                                 # "," separator
    ProcessedData.write(str(Median_Z_V))                     # 1 minute average Z(V)
    ProcessedData.write(",")                                 # "," separator
    ProcessedData.write(str(Median_X_nT))                    # 1 minute average X(nT)
    ProcessedData.write(",")                                 # "," separator
    ProcessedData.write(str(Median_Y_nT))                    # 1 minute average Y(nT)
    ProcessedData.write(",")                                 # "," separator
    ProcessedData.write(str(Median_Z_nT))                    # 1 minute average Z(nT)
    ProcessedData.write(",")                                 # "," separator
    ProcessedData.write(str(Median_TMP36_degC))              # 1 minute average TMP36 temperature
    ProcessedData.write(",")                                 # "," separator
    ProcessedData.write(str(Median_Delta_nT))                # 1 minute average Delta(nT)
    ProcessedData.write(",")                                 # "," separator
    ProcessedData.write(str(Calc_H))                         # Calculated H value
    ProcessedData.write(",")                                 # "," separator
    ProcessedData.write(str(Calc_D))                         # Calculated D value
    ProcessedData.write(",")                                 # "," separator
    ProcessedData.write(str(Calc_Z))                         # Calculated Z value
    ProcessedData.write(",")                                 # "," separator
    ProcessedData.write(str(Calc_B))                         # Calculated B value
    ProcessedData.write(",")                                 # "," separator
    ProcessedData.write(str(Calc_I))                         # Calculated I value
    ProcessedData.write(",")                                 # "," separator
    ProcessedData.write(str(RawLine['RawDetectorName']))     # Detector name
    ProcessedData.write("\n")                                # new line

# close open ProcessedData file
ProcessedData.close()

# =============================================================================
# Message to log file at end of program

# print message to log file to say completed
print('ProcessDataRawACM0.py :', \
      datetime.datetime.strftime(datetime.datetime.now(), '%Y-%m-%d %H:%M:%S'), \
      ': Completed processing yesterdays magnetometer data for', \
      datetime.datetime.strftime(datetime.datetime.now() - datetime.timedelta(1), '%Y-%m-%d'))
      

# =============================================================================
# END of program