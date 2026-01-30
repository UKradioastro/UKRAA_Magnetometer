#!/bin/bash

#echo "Start moving yesterday's graphs for webpage..."

# entry to move yesterdays graphs from temp to /var/www/html
cp -r /home/pi/UKRAA_Magnetometer/temp /var/www/html/ \
   >> /home/pi/UKRAA_Magnetometer/logfiles/log-MagnetometerACM0.txt \
  2>> /home/pi/UKRAA_Magnetometer/logfiles/log-error.txt

#echo "Completed moving yesterday's graphs for webpage"
