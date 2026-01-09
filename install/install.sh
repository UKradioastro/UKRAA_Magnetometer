#!/bin/bash


echo "Start installing UKRAA Magnetometer software..."


echo "Start installing gnuplot software..."
apt install gnuplot -y
apt install gnuplot-doc -y
apt install gnuplot-x11 -y
echo "gnuplot software installed"

echo "Creating UKRAA Magnetometer directory structure..."
sudo -u pi mkdir -vp /home/pi/UKRAA_Magnetometer/data/processed
sudo -u pi mkdir -vp /home/pi/UKRAA_Magnetometer/data/raw
sudo -u pi mkdir -v  /home/pi/UKRAA_Magnetometer/logfiles
sudo -u pi mkdir -vp /home/pi/UKRAA_Magnetometer/plots/3month/ACM0
sudo -u pi mkdir -vp /home/pi/UKRAA_Magnetometer/plots/BI
sudo -u pi mkdir -vp /home/pi/UKRAA_Magnetometer/plots/HDZ
sudo -u pi mkdir -vp /home/pi/UKRAA_Magnetometer/plots/XYZ
sudo -u pi mkdir -v  /home/pi/UKRAA_Magnetometer/temp
sudo -u pi mkdir -vp /home/pi/UKRAA_Magnetometer/WWW/temp
echo "UKRAA Magnetometer directory structure created"

echo "Sort out UKRAA Magnetometer file permissions..."
sudo -u pi chmod -v +x /home/pi/UKRAA_Magnetometer/scripts/*.py
sudo -u pi chmod -v +x /home/pi/UKRAA_Magnetometer/scripts/*.sh
echo "UKRAA Magnetometer file permissions sorted out"


echo "Start installing MagnetometerACM0.service..."
cp -vf /home/pi/UKRAA_Magnetometer/install/MagnetometerACM0.service /etc/systemd/system
chmod -v 644 /etc/systemd/system/MagnetometerACM0.service
systemctl daemon-reload
systemctl enable MagnetometerACM0.service
systemctl start MagnetometerACM0.service
echo "MagnetometerACM0.service installed and started"

echo "Start installing UKRAA Magnetometer crontab entry..."
echo "Clearing current crontab entry..."
echo "NOTE: if you have edited your sudo crontab - this will be deleted.  You will need to reedit sudo crontab post update."
sudo crontab -u root -r
sudo crontab -u root -l  | cat - /home/pi/UKRAA_Magnetometer/install/crontab-magnetometerACM0-entry.cron | sudo crontab -u root -
echo "UKRAA Magnetometer crontab entry installed"

cho "Start installing UKRAA Magnetometer log file manager update crontab entry..."
sudo crontab -u root -l | cat - /home/pi/UKRAA_Magnetometer/install/crontab-managelogfiles.cron | sudo crontab -u root -
echo "UKRAA Magnetometer log file update crontab entry installed"


echo "Start installing web server on RPi..."

echo "Update packages..."
apt update

echo "Install apache2..."
apt install apache2 -y

echo "Install php..."
apt install php libapache2-mod-php -y

echo "Install mariadb..."
apt install mariadb-server -y
mysql_secure_installation

echo "Install the php-mysql connector..."
apt install php-mysql -y

echo "Restart apache2..."
service apache2 restart
echo "web server installed on RPi"


echo "Move files to /var/www/html..."
cp -v /home/pi/UKRAA_Magnetometer/WWW/index.html /var/www/html/index.html
cp -vr /home/pi/UKRAA_Magnetometer/WWW/images /var/www/html/
cp -vr /home/pi/UKRAA_Magnetometer/WWW/temp /var/www/html/
echo "Files moved to /var/www/html"

echo "Start installing UKRAA Magnetometer webpage update crontab entry..."
sudo crontab -u root -l | cat - /home/pi/UKRAA_Magnetometer/install/crontab-webpage-update-entry.cron | sudo crontab -u root -
echo "UKRAA Magnetometer webpage update crontab entry installed"

echo "Final cleanup..."
sudo -u pi rm -vrf /home/pi/UKRAA_Magnetometer/WWW
sudo -u pi rm -v /home/pi/UKRAA_Magnetometer/README.md
echo "Finished final cleanup"

echo "Completed installing UKRAA Magnetometer software."
sleep 10

# if successful
echo "Removing install directory and exiting..."
exec rm -vrf /home/pi/UKRAA_Magnetometer/install