#!/usr/bin/env python3

#imports
import datetime
import csv
import os
import math
import statistics

# print message to log file to say started

print('ProcessDataRawACM0.py      :', \
      datetime.datetime.strftime(datetime.datetime.now(), '%Y-%m-%d %H:%M:%S'), \
      ': Started processing yesterdays magnetometer data for', \
      datetime.datetime.strftime(datetime.datetime.now() - datetime.timedelta(1), '%Y-%m-%d'))

# Set file headers for data file structure
RawFieldNames    = ['RawDateTime',\
                    'RawX', \
                    'RawY', \
                    'RawZ', \
                    'RawTMP36Temp', \
                    'RawBMP280Temp', \
                    'RawBMP280Pres', \
                    'RawName']

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
    print('ProcessDataRawACM0.py      :', \
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
    List_X            = list()
    List_Y            = list()
    List_Z            = list()
    List_TMP36Temp    = list()
    List_BMP280Temp   = list()
    List_BMP280Pres   = list()
    Median_X          = 0.000000
    Median_Y          = 0.000000
    Median_Z          = 0.000000
    Median_TMP36Temp  = 0.00
    Median_BMP280Temp = 0.00
    Median_BMP280Pres = 0.00
    Calc_H            = 0.000000
    Calc_D            = 0.0
    Calc_Z            = 0.000000
    Calc_B            = 0.000000
    Calc_I            = 0.0
    

    for RawLine in RawCSV_reader:
        # try to get raw data after start StartBinTime
        # convert string to datetime.datetime format
        RawDatetime = datetime.datetime.strptime(RawLine['RawDateTime'], 
                                                 '%Y-%m-%d %H:%M:%S')
        
        # search file for data between two time points
        if (RawDatetime >= StartBinTime) and (RawDatetime < EndBinTime):
            List_X.append(float(RawLine['RawX']))
            List_Y.append(float(RawLine['RawY']))
            List_Z.append(float(RawLine['RawZ']))
            List_TMP36Temp.append(float(RawLine['RawTMP36Temp']))
            List_BMP280Temp.append(float(RawLine['RawBMP280Temp']))
            List_BMP280Pres.append(float(RawLine['RawBMP280Pres']))
            
    # close open RawFile
    RawFile.close()

    
    # check if there is some x-axis data
    if (len(List_X) != 0):
        Median_X = '{:.6f}'.format(statistics.median(List_X))
    else:
        Median_X = math.nan
        
    # check if there is some y-axis data
    if (len(List_Y) != 0):
        Median_Y = '{:.6f}'.format(statistics.median(List_Y))
    else:
        Median_Y = math.nan
        
    # check if there is some z-axis data
    if (len(List_Z) != 0):
        Median_Z = '{:.6f}'.format(statistics.median(List_Z))
    else:
        Median_Z = math.nan
        
    # check if there is some TMP36 temp data
    if (len(List_TMP36Temp) != 0):
        Median_TMP36Temp = '{:.2f}'.format(statistics.median(List_TMP36Temp))
    else:
        Median_TMP36Temp = math.nan
        
    # check if there is some BMP280 temp data
    if (len(List_BMP280Temp) != 0):
        Median_BMP280Temp = '{:.2f}'.format(statistics.median(List_BMP280Temp))
    else:
        Median_BMP280Temp = math.nan

    # check if there is some BMP280 pres data
    if (len(List_BMP280Pres) != 0):
        Median_BMP280Pres = '{:.2f}'.format(statistics.median(List_BMP280Pres))
    else:
        Median_BMP280Pres = math.nan


    # Process XYZ data to HDZ data
    Calc_H = '{:.6f}'.format(math.sqrt((float(Median_X) * float(Median_X)) + (float(Median_Y) * float(Median_Y))))
    if (Calc_H == 0):
        Calc_H = math.nan
    Calc_D = '{:.1f}'.format(math.degrees(math.atan(float(Median_Y) / float(Median_X))))
    if (Calc_D == 0):
        Calc_D = math.nan
    Calc_Z = '{:.6f}'.format(float(Median_Z))
    if (Calc_Z == 0):
        Calc_Z = math.nan
    Calc_B = '{:.6f}'.format(math.sqrt((float(Median_X) * float(Median_X)) + (float(Median_Y) * float(Median_Y)) + (float(Median_Z) * float(Median_Z))))
    if (Calc_B == 0):
        Calc_B = math.nan
    Calc_I = '{:.1f}'.format(math.degrees(math.atan(float(Calc_Z) / float(Calc_H))))
    if (Calc_I == 0):
        Calc_I = math.nan


    # write processed data to file
    ProcessedData.write(str(ProcessedTime))          # Data time date
    ProcessedData.write(",")                         # "," separator
    ProcessedData.write(str(Median_X))               # 1 minute average X
    ProcessedData.write(",")                         # "," separator
    ProcessedData.write(str(Median_Y))               # 1 minute average Y
    ProcessedData.write(",")                         # "," separator
    ProcessedData.write(str(Median_Z))               # 1 minute average Z
    ProcessedData.write(",")                         # "," separator
    ProcessedData.write(str(Median_TMP36Temp))       # 1 minute average TMP36 temperature
    ProcessedData.write(",")                         # "," separator
    ProcessedData.write(str(Median_BMP280Temp))      # 1 minute average BMP280 temperature
    ProcessedData.write(",")                         # "," separator
    ProcessedData.write(str(Median_BMP280Pres))      # 1 minute average PMP280 pressure
    ProcessedData.write(",")                         # "," separator
    ProcessedData.write(str(Calc_H))                 # Calculated H value
    ProcessedData.write(",")                         # "," separator
    ProcessedData.write(str(Calc_D))                 # Calculated D value
    ProcessedData.write(",")                         # "," separator
    ProcessedData.write(str(Calc_Z))                 # Calculated Z value
    ProcessedData.write(",")                         # "," separator
    ProcessedData.write(str(Calc_B))                 # Calculated B value
    ProcessedData.write(",")                         # "," separator
    ProcessedData.write(str(Calc_I))                 # Calculated I value
    ProcessedData.write(",")                         # "," separator
    ProcessedData.write(str(RawLine['RawName']))     # Detector name
    ProcessedData.write("\n")                        # new line

# close open ProcessedData file
ProcessedData.close()

# =============================================================================
# Message to log file at end of program

# print message to log file to say completed
print('ProcessDataRawACM0.py      :', \
      datetime.datetime.strftime(datetime.datetime.now(), '%Y-%m-%d %H:%M:%S'), \
      ': Completed processing yesterdays magnetometer data for', \
      datetime.datetime.strftime(datetime.datetime.now() - datetime.timedelta(1), '%Y-%m-%d'))
      

# =============================================================================
# END of program