# imports
import serial
import os

from magnetometer_common import build_raw_day_path
from magnetometer_common import build_raw_month_path
from magnetometer_common import ensure_directory
from magnetometer_common import get_base_path
from magnetometer_common import utc_now

# main
def main():
    base_path = get_base_path()

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
            current_time = utc_now()

            # path for data storage
            path = build_raw_month_path(base_path, current_time)
            # check if the specific path exists
            pathExists = os.path.exists(path)
            if not pathExists:
                # create directory structure
                ensure_directory(path)
            # if data write to file
            if line:
                timetowrite = current_time.strftime('%Y-%m-%d %H:%M:%S')
                texttowrite = (line.decode('utf-8', 'ignore').strip())
                outfilePath = build_raw_day_path(base_path, current_time)

                with open(outfilePath, mode='a', encoding='UTF-8') as outfile:
                    print(timetowrite
                        + ','
                        + texttowrite
                        , file = outfile)
    finally:
        ser.close()
        
                        
if __name__ == "__main__":
    main()