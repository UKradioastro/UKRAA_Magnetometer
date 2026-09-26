#!/bin/bash

if [ "$(id -u)" -ne 0 ]; then
	echo "Run the installer with sudo." >&2
	exit 1
fi

FILE_OWNER=${MAGNETOMETER_FILE_OWNER:-${SUDO_USER:-}}
if [ -z "$FILE_OWNER" ] || [ "$FILE_OWNER" = root ] || ! id "$FILE_OWNER" >/dev/null 2>&1; then
	echo "Specify a non-root installation account with sudo or MAGNETOMETER_FILE_OWNER." >&2
	exit 1
fi

USER_HOME=$(getent passwd "$FILE_OWNER" | cut -d: -f6)
BASE_PATH="$USER_HOME/UKRAA_Magnetometer"
SOURCE_PATH=$(readlink -f "$(dirname "${BASH_SOURCE[0]}")/..")
if [ -z "$USER_HOME" ] || [ "$SOURCE_PATH" != "$BASE_PATH" ] || [[ ! "$BASE_PATH" =~ ^/[A-Za-z0-9_./-]+$ ]]; then
	echo "Install from $BASE_PATH (only letters, digits, dots, underscores, hyphens and slashes are supported in paths)." >&2
	exit 1
fi
if [ "$(stat -c %U "$BASE_PATH")" != "$FILE_OWNER" ]; then
	echo "The installation directory must be owned by $FILE_OWNER." >&2
	exit 1
fi
export MAGNETOMETER_BASE_PATH="$BASE_PATH" MAGNETOMETER_FILE_OWNER="$FILE_OWNER"
FILE_GROUP=$(id -gn "$FILE_OWNER")
SHORT_HOSTNAME=$(hostname -s)
if [ "${#SHORT_HOSTNAME}" -gt 63 ] || [[ ! "$SHORT_HOSTNAME" =~ ^[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?$ ]]; then
	echo "Cannot create a .local URL from hostname: $SHORT_HOSTNAME" >&2
	exit 1
fi

RUN_HEARTBEAT_SMOKE_CHECK=0

if [ "${MAGNETOMETER_INSTALL_SMOKE_HEARTBEAT:-}" = "1" ]; then
	RUN_HEARTBEAT_SMOKE_CHECK=1
fi

NEW_VERSION=$(cat "$BASE_PATH/VERSION" 2>/dev/null || echo "unknown")
INSTALLED_VERSION_FILE="$BASE_PATH/config/installed-version.txt"
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
sudo -u "$FILE_OWNER" cp -v "$BASE_PATH/images/wallpaperPicoMagnetometer.png" "$USER_HOME/Pictures/wallpaperPicoMagnetometer.png"
echo "RPi desktop wallpaper provided, ~/Pictures/wallpaperPicoMagnetometer.png"
echo ""

echo "Creating UKRAA Magnetometer directory structure..."
for directory in data/{minute,hour,raw,kp,daily,rolling,status} \
	logfiles plots/day/{Activity,BI,HDZ,XYZ} plots/{rolling,kp} \
	config temp/{kp,noaa,rolling,yesterday,periods} WWW/temp; do
	sudo -u "$FILE_OWNER" mkdir -vp "$BASE_PATH/$directory"
done
chown -R "$FILE_OWNER:$FILE_GROUP" "$BASE_PATH/data/kp" "$BASE_PATH/temp/kp" "$BASE_PATH/plots/kp"
echo "UKRAA Magnetometer directory structure created"
echo ""

echo "Creating UKRAA Magnetometer log files..."
# cron runs the wrapper scripts as root, but the work steps drop to the installation account.
# Pre-create log files under that account so redirections do not become root-owned.
for logFile in log-Magnetometer.txt log-error.txt dashboard-summary.log; do
	sudo -u "$FILE_OWNER" touch "$BASE_PATH/logfiles/$logFile"
done
chown -v "$FILE_OWNER:$FILE_GROUP" "$BASE_PATH/logfiles" "$BASE_PATH"/logfiles/*
chmod -v 664 "$BASE_PATH"/logfiles/*
echo "UKRAA Magnetometer log files created"
echo ""

set_up_configuration() {
	local description=$1
	local template_path=$2
	local config_path=$3

	echo "Set up $description configuration..."
	if [ ! -f "$config_path" ]; then
		sudo -u "$FILE_OWNER" cp -v "$template_path" "$config_path"
		if [ "$description" = "rolling alert" ]; then
			sudo -u "$FILE_OWNER" /usr/bin/python3 "$BASE_PATH/scripts/MergeConfig.py" \
				--set-web-url "http://${SHORT_HOSTNAME,,}.local" "$template_path" "$config_path"
		fi
		echo "Created $config_path"
	else
		echo "Retaining existing values in $config_path"
		sudo -u "$FILE_OWNER" /usr/bin/python3 "$BASE_PATH/scripts/MergeConfig.py" \
			"$template_path" "$config_path"
	fi
	echo ""
}

set_up_configuration "rolling alert" \
	"$BASE_PATH/install/alerts.ini.example" \
	"$BASE_PATH/config/alerts.ini"
set_up_configuration "remote upload" \
	"$BASE_PATH/install/remote-upload.ini.example" \
	"$BASE_PATH/config/remote-upload.ini"
set_up_configuration "plot" \
	"$BASE_PATH/install/plot.ini.example" \
	"$BASE_PATH/config/plot.ini"
set_up_configuration "USB" \
	"$BASE_PATH/install/USB.ini.example" \
	"$BASE_PATH/config/USB.ini"

echo "Sort out UKRAA Magnetometer file permissions..."
sudo -u "$FILE_OWNER" chmod -v +x "$BASE_PATH"/scripts/*.py
sudo -u "$FILE_OWNER" chmod -v +x "$BASE_PATH"/scripts/*.sh
echo "UKRAA Magnetometer file permissions sorted out"
echo ""


echo "Migrating the magnetometer collector service..."
if ! /usr/bin/python3 "$BASE_PATH/scripts/InstallMagnetometerService.py" \
	"$BASE_PATH/install/PicoMagnetometer.service" \
	--account "$FILE_OWNER" --base-path "$BASE_PATH"; then
	echo "Failed to install or start PicoMagnetometer.service"
	exit 1
fi
if ! /bin/bash "$BASE_PATH/scripts/testCollectorService.sh"; then
	echo "Collector service validation failed"
	exit 1
fi
echo ""

echo "Start installing UKRAA Magnetometer crontab entry..."
echo "Updating current crontab entry..."
tmpCronFile=$(mktemp)
sudo crontab -u root -l 2>/dev/null | grep -v 'UKRAA_Magnetometer' | grep -v '^MAGNETOMETER_\(BASE_PATH\|FILE_OWNER\)=' > "$tmpCronFile"
printf 'MAGNETOMETER_BASE_PATH=%s\nMAGNETOMETER_FILE_OWNER=%s\n' "$BASE_PATH" "$FILE_OWNER" >> "$tmpCronFile"
sed "s|@MAGNETOMETER_BASE_PATH@|$BASE_PATH|g" "$BASE_PATH/install/crontabMagnetometer.cron" >> "$tmpCronFile"
sudo crontab -u root "$tmpCronFile"
rm -f "$tmpCronFile"
if ! /usr/bin/python3 "$BASE_PATH/scripts/MigrateLegacyInstall.py" \
	--base-path "$BASE_PATH"; then
	echo "Failed to migrate legacy ACM0-named files and logs"
	exit 1
fi
chown -v "$FILE_OWNER:$FILE_GROUP" "$BASE_PATH/logfiles" "$BASE_PATH"/logfiles/*
chmod -v 664 "$BASE_PATH"/logfiles/*
echo "UKRAA Magnetometer crontab entry installed"
echo ""


if [ "$RUN_HEARTBEAT_SMOKE_CHECK" -eq 1 ]; then
	echo "Running optional heartbeat smoke check..."
	if su "$FILE_OWNER" -c "/usr/bin/python3 $BASE_PATH/scripts/EvaluateAlerts.py --test-heartbeat"; then
		echo "HEARTBEAT_SMOKE_CHECK: PASS"
	else
		smoke_exit_code=$?
		echo "HEARTBEAT_SMOKE_CHECK: FAIL (exit code $smoke_exit_code)"
		echo "Check SMTP settings in $BASE_PATH/config/alerts.ini"
		echo "Retry command: /bin/bash $BASE_PATH/scripts/testHeartbeatEmail.sh"
	fi
else
	echo "Skipping optional heartbeat smoke check (default)."
	echo "Enable it with: sudo MAGNETOMETER_INSTALL_SMOKE_HEARTBEAT=1 bash ~/UKRAA_Magnetometer/install/install.sh"
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
cp -v "$BASE_PATH/WWW/index.html" /var/www/html/index.html
cp -vr "$BASE_PATH/WWW/images" /var/www/html/
cp -vr "$BASE_PATH/WWW/temp" /var/www/html/
echo "Files moved to /var/www/html"
echo ""


echo "Final cleanup..."
sudo -u "$FILE_OWNER" rm -vrf "$BASE_PATH/docs" "$BASE_PATH/images" "$BASE_PATH/tests" "$BASE_PATH/WWW"
sudo -u "$FILE_OWNER" rm -vf "$BASE_PATH/README.md"
echo "Finished final cleanup"
echo ""

echo "$NEW_VERSION" | sudo -u "$FILE_OWNER" tee "$INSTALLED_VERSION_FILE" > /dev/null

echo "Completed installing UKRAA Magnetometer software."
echo ""
sleep 10

# if successful
echo "Removing install directory and exiting..."
cd "$USER_HOME" || cd /
rm -vrf "$BASE_PATH/install"
echo ""

echo "Finished installing UKRAA Magnetometer software..."
echo ""
echo "NOTE: the install directory you launched this from has just been deleted."
echo "      Run 'cd ~' before any further commands, otherwise your shell will"
echo "      report: getcwd: cannot access parent directories"