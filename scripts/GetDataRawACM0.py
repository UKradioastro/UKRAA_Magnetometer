# imports
from datetime import datetime, timezone
import serial
import os

# main
def main():
    # set up usb serial variables
    ser = serial.Serial(port = '/dev/ttyACM0',
                        baudrate = 115200,
                        bytesize = serial.EIGHTBITS,
                        parity = serial.PARITY_NONE,
                        stopbits = serial.STOPBITS_ONE,
                        timeout = None,
                        xonxoff = True,
                        rtscts = False,
                        write_timeout = None,
                        dsrdtr = False,
                        inter_byte_timeout = None,
                        exclusive = None)

    try:
        for line in ser:
            # path for data storage
            path = '/home/pi/UKRAA_Magnetometer/data/raw/'\
                    + datetime.strftime(datetime.now(timezone.utc), '%Y')\
                    + '/'\
                    + datetime.strftime(datetime.now(timezone.utc), '%Y-%m')
            # check if the specific path exists
            pathExists = os.path.exists(path)
            if not pathExists:
                # create directory structure
                os.makedirs(path, exist_ok=True)
            # if data write to file
            if line:
                timetowrite = (datetime.strftime(datetime.now(timezone.utc), '%Y-%m-%d')
                            + " "
                            + datetime.strftime(datetime.now(timezone.utc), '%H:%M:%S'))
                texttowrite = (line.decode('utf-8', 'ignore').strip())
                outfilePath = '/home/pi/UKRAA_Magnetometer/data/raw/'
                outfilePath += datetime.strftime(datetime.now(timezone.utc), '%Y')
                outfilePath += '/'
                outfilePath += datetime.strftime(datetime.now(timezone.utc), '%Y-%m')
                outfilePath += '/'
                outfilePath += datetime.strftime(datetime.now(timezone.utc), '%Y-%m-%d')
                outfilePath += '.csv'

                with open(outfilePath, mode='a', encoding='UTF-8') as outfile:
                    print(timetowrite
                        + ','
                        + texttowrite
                        , file = outfile)
    finally:
        ser.close()
        
                        
if __name__ == "__main__":
    main()