#!/bin/bash

RUN_HEARTBEAT_SMOKE_CHECK=0

if [ "${MAGNETOMETER_INSTALL_SMOKE_HEARTBEAT:-}" = "1" ]; then
	RUN_HEARTBEAT_SMOKE_CHECK=1
fi

NEW_VERSION=$(cat /home/pi/UKRAA_Magnetometer/VERSION 2>/dev/null || echo "unknown")
INSTALLED_VERSION_FILE=/home/pi/UKRAA_Magnetometer/config/installed-version.txt
OLD_VERSION=""
if [ -f "$INSTALLED_VERSION_FILE" ]; then
	OLD_VERSION=$(cat "$INSTALLED_VERSION_FILE")
fi

if [ -z "$OLD_VERSION" ]; then
	echo "Fresh install: v$NEW_VERSION"
elif [ "$OLD_VERSION" = "$NEW_VERSION" ]; then
	echo "Re-running install for existing v$NEW_VERSION (no version change)"
else
	echo "Upgrading UKRAA Magnetometer: v$OLD_VERSION -> v$NEW_VERSION"
fi


echo "Start installing UKRAA Magnetometer software..."
echo ""

echo "Start installing gnuplot software..."
apt install gnuplot -y
apt install gnuplot-doc -y
echo "gnuplot software installed"
echo ""

echo "Start installing curl software..."
apt install curl -y
echo "curl software installed"
echo ""

echo "Start installing unzip software..."
apt install unzip -y
echo "unzip software installed"
echo ""

echo "Provide RPi desktop wallpaper..."
sudo -u pi cp -v  /home/pi/UKRAA_Magnetometer/images/wallpaperPicoMagnetometer.png /home/pi/Pictures/wallpaperPicoMagnetometer.png
echo "RPi desktop wallpaper provided, ~/Pictures/wallpaperPicoMagnetometer.png"
echo ""

echo "Creating UKRAA Magnetometer directory structure..."
sudo -u pi mkdir -vp /home/pi/UKRAA_Magnetometer/data/minute
sudo -u pi mkdir -vp /home/pi/UKRAA_Magnetometer/data/hour
sudo -u pi mkdir -vp /home/pi/UKRAA_Magnetometer/data/raw
sudo -u pi mkdir -vp /home/pi/UKRAA_Magnetometer/logfiles
sudo -u pi mkdir -vp /home/pi/UKRAA_Magnetometer/plots/Activity
sudo -u pi mkdir -vp /home/pi/UKRAA_Magnetometer/plots/BI
sudo -u pi mkdir -vp /home/pi/UKRAA_Magnetometer/plots/HDZ
sudo -u pi mkdir -vp /home/pi/UKRAA_Magnetometer/plots/XYZ
sudo -u pi mkdir -vp /home/pi/UKRAA_Magnetometer/plots/rolling
sudo -u pi mkdir -vp /home/pi/UKRAA_Magnetometer/plots/kp
sudo -u pi mkdir -vp /home/pi/UKRAA_Magnetometer/data/kp
sudo -u pi mkdir -vp /home/pi/UKRAA_Magnetometer/data/rolling
sudo -u pi mkdir -vp /home/pi/UKRAA_Magnetometer/data/status
sudo -u pi mkdir -vp /home/pi/UKRAA_Magnetometer/config
sudo -u pi mkdir -vp /home/pi/UKRAA_Magnetometer/temp/kp
sudo -u pi mkdir -vp /home/pi/UKRAA_Magnetometer/temp/noaa
sudo -u pi mkdir -vp /home/pi/UKRAA_Magnetometer/temp/rolling
sudo -u pi mkdir -vp /home/pi/UKRAA_Magnetometer/WWW/temp
chown -R pi:pi /home/pi/UKRAA_Magnetometer/data/kp /home/pi/UKRAA_Magnetometer/temp/kp /home/pi/UKRAA_Magnetometer/plots/kp
echo "UKRAA Magnetometer directory structure created"
echo ""

echo "Creating UKRAA Magnetometer log files..."
# cron runs the wrapper scripts as root, but the work steps drop to user pi with su.
# Pre-create the log files as pi so those redirections are not blocked by root ownership.
for logFile in log-MagnetometerACM0.txt log-error.txt dashboard-summary.log; do
	sudo -u pi touch /home/pi/UKRAA_Magnetometer/logfiles/"$logFile"
done
chown -v pi:pi /home/pi/UKRAA_Magnetometer/logfiles /home/pi/UKRAA_Magnetometer/logfiles/*
chmod -v 664 /home/pi/UKRAA_Magnetometer/logfiles/*
echo "UKRAA Magnetometer log files created"
echo ""

echo "Set up default rolling alert configuration..."
if [ ! -f /home/pi/UKRAA_Magnetometer/config/alerts.ini ]; then
	sudo -u pi cp -v /home/pi/UKRAA_Magnetometer/install/alerts.ini.example /home/pi/UKRAA_Magnetometer/config/alerts.ini
	echo "Created /home/pi/UKRAA_Magnetometer/config/alerts.ini"
else
	echo "Existing /home/pi/UKRAA_Magnetometer/config/alerts.ini retained"
fi
echo ""

echo "Set up default remote upload configuration..."
if [ ! -f /home/pi/UKRAA_Magnetometer/config/remote-upload.ini ]; then
	sudo -u pi cp -v /home/pi/UKRAA_Magnetometer/install/remote-upload.ini.example /home/pi/UKRAA_Magnetometer/config/remote-upload.ini
	echo "Created /home/pi/UKRAA_Magnetometer/config/remote-upload.ini"
else
	echo "Existing /home/pi/UKRAA_Magnetometer/config/remote-upload.ini retained"
fi
echo ""

echo "Set up default plot configuration..."
if [ ! -f /home/pi/UKRAA_Magnetometer/config/plot.ini ]; then
	sudo -u pi cp -v /home/pi/UKRAA_Magnetometer/install/plot.ini.example /home/pi/UKRAA_Magnetometer/config/plot.ini
	echo "Created /home/pi/UKRAA_Magnetometer/config/plot.ini"
else
	echo "Existing /home/pi/UKRAA_Magnetometer/config/plot.ini retained"
fi
echo ""

echo "Sort out UKRAA Magnetometer file permissions..."
sudo -u pi chmod -v +x /home/pi/UKRAA_Magnetometer/scripts/*.py
sudo -u pi chmod -v +x /home/pi/UKRAA_Magnetometer/scripts/*.sh
sudo -u pi chmod -v +x /home/pi/UKRAA_Magnetometer/scripts/testAlertEmailACM0.sh
sudo -u pi chmod -v +x /home/pi/UKRAA_Magnetometer/scripts/testHeartbeatEmailACM0.sh
sudo -u pi chmod -v +x /home/pi/UKRAA_Magnetometer/scripts/uploadRemoteACM0.sh
sudo -u pi chmod -v +x /home/pi/UKRAA_Magnetometer/scripts/testRemoteUploadACM0.sh
echo "UKRAA Magnetometer file permissions sorted out"
echo ""


echo "Start installing PicoMagnetometerACM0.service..."
cp -vf /home/pi/UKRAA_Magnetometer/install/PicoMagnetometerACM0.service /etc/systemd/system
chmod -v 644 /etc/systemd/system/PicoMagnetometerACM0.service
systemctl daemon-reload
systemctl enable PicoMagnetometerACM0.service
systemctl start PicoMagnetometerACM0.service
echo "PicoMagnetometerACM0.service installed and started"
echo ""

echo "Start installing UKRAA Magnetometer crontab entry..."
echo "Updating current crontab entry..."
tmpCronFile=$(mktemp)
sudo crontab -u root -l 2>/dev/null | grep -v 'UKRAA_Magnetometer' > "$tmpCronFile"
cat /home/pi/UKRAA_Magnetometer/install/crontabMagnetometerACM0.cron >> "$tmpCronFile"
sudo crontab -u root "$tmpCronFile"
rm -f "$tmpCronFile"
echo "UKRAA Magnetometer crontab entry installed"
echo ""


if [ "$RUN_HEARTBEAT_SMOKE_CHECK" -eq 1 ]; then
	echo "Running optional heartbeat smoke check..."
	if MAGNETOMETER_BASE_PATH=/home/pi/UKRAA_Magnetometer su pi -c "/usr/bin/python3 /home/pi/UKRAA_Magnetometer/scripts/EvaluateAlertsACM0.py --test-heartbeat"; then
		echo "HEARTBEAT_SMOKE_CHECK: PASS"
	else
		smoke_exit_code=$?
		echo "HEARTBEAT_SMOKE_CHECK: FAIL (exit code $smoke_exit_code)"
		echo "Check SMTP settings in /home/pi/UKRAA_Magnetometer/config/alerts.ini"
		echo "Retry command: /bin/bash /home/pi/UKRAA_Magnetometer/scripts/testHeartbeatEmailACM0.sh"
	fi
else
	echo "Skipping optional heartbeat smoke check (default)."
	echo "Enable it with: sudo MAGNETOMETER_INSTALL_SMOKE_HEARTBEAT=1 bash install.sh"
fi
echo ""


echo "Start installing web server on RPi..."
echo ""

echo "Update packages..."
apt update
echo "Finished updating packages"
echo ""

echo "Install apache2..."
apt install apache2 -y
echo "Finished installing apache2"
echo ""

echo "Install php..."
apt install php libapache2-mod-php -y
echo "Finished installing php"
echo ""

echo "Install mariadb..."
apt install mariadb-server -y
#mariadb-secure-installation
echo "Finished installing mariadb"
echo ""

echo "Install the php-mysql connector..."
apt install php-mysql -y
echo "Finished installing php-mysql connector"
echo ""

echo "Restart apache2..."
service apache2 restart
echo "Retarted apache2 service"
echo ""

echo "Finished installing web server on RPi"
echo ""


echo "Move files to /var/www/html..."
cp -v  /home/pi/UKRAA_Magnetometer/WWW/index.html /var/www/html/index.html
cp -vr /home/pi/UKRAA_Magnetometer/WWW/images /var/www/html/
cp -vr /home/pi/UKRAA_Magnetometer/WWW/temp /var/www/html/
echo "Files moved to /var/www/html"
echo ""


echo "Final cleanup..."
sudo -u pi rm -vrf /home/pi/UKRAA_Magnetometer/docs
sudo -u pi rm -vrf /home/pi/UKRAA_Magnetometer/images
sudo -u pi rm -vrf /home/pi/UKRAA_Magnetometer/WWW
sudo -u pi rm -vf  /home/pi/UKRAA_Magnetometer/README.md
echo "Finished final cleanup"
echo ""

echo "$NEW_VERSION" | sudo -u pi tee /home/pi/UKRAA_Magnetometer/config/installed-version.txt > /dev/null

echo "Completed installing UKRAA Magnetometer software."
echo ""
sleep 10

# if successful
echo "Removing install directory and exiting..."
cd /home/pi || cd /
rm -vrf /home/pi/UKRAA_Magnetometer/install
echo ""

echo "Finished installing UKRAA Magnetometer software..."
echo ""
echo "NOTE: the install directory you launched this from has just been deleted."
echo "      Run 'cd ~' before any further commands, otherwise your shell will"
echo "      report: getcwd: cannot access parent directories"