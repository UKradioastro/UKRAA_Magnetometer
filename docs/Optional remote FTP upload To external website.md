### Optional remote FTP upload to external website

You can upload plot PNG files to an external Hostinger site while keeping local web publishing as the primary path.

Remote upload config file:

* `/home/pi/UKRAA_Magnetometer/config/remote-upload.ini`

Template created by installer:

* `install/remote-upload.ini.example`

Example settings:

```
[ftp]
enabled = true
site = your-uploader-fp
user = your-upload-user
password = your-upload-password
port = 21
directory = /data
timeout_seconds = 30
passive = true
create_dirs = true
upload_status_json = false
```

Behavior:

* Daily run (09:30 via `moveGraphs.sh`) uploads:
	* `Activity.png`, `X.png`, `Y.png`, `Z.png` to `/data`
* Rolling run (every 5 minutes via `processRollingData.sh`) uploads:
	* `RollingActivity.png`, `RollingXYZ.png` to `/data/rolling`
* Optional rolling status JSON upload:
	* set `upload_status_json = true`
	* uploads `data/status/current.json` to `/data/status/current.json`
	* external webpage status fallback (`status/current.json`) requires this to be true.
* Remote upload failures are non-blocking and do not stop local publishing.

Manual test commands:

```
/bin/bash /home/pi/UKRAA_Magnetometer/scripts/uploadRemoteACM0.sh daily
/bin/bash /home/pi/UKRAA_Magnetometer/scripts/uploadRemoteACM0.sh rolling
```

Combined test helper:

```
/bin/bash /home/pi/UKRAA_Magnetometer/scripts/testRemoteUploadACM0.sh
```
