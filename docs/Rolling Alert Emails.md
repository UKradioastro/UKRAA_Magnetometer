## Rolling alert emails

Rolling alert evaluation now supports AuroraWatch-style activity thresholds:

* **Yellow** at **50 nT**
* **Amber** at **100 nT**
* **Red** at **200 nT**

The alert evaluator runs as part of `processRollingData.sh` and only sends email on threshold transitions to levels you choose.

The same threshold values are also used by:

* Daily hourly Activity plot (`PlotDataActivityACM0.gp`)
* Rolling Activity plot (`PlotRollingActivityACM0.gp`)

### Configure via `.ini` file (recommended)

1. Copy the example file:
	`install/alerts.ini.example`

2. Place it on the Pi as:
	`/home/pi/UKRAA_Magnetometer/config/alerts.ini`

3. Edit the values for your SMTP service and recipients.

4. Set activity thresholds in the same file under `[alerts]`:

```
[alerts]
yellow_threshold_nt = 50
amber_threshold_nt = 100
red_threshold_nt = 200
```

By default, `EvaluateAlertsACM0.py` reads:
`/home/pi/UKRAA_Magnetometer/config/alerts.ini`

You can override the config path with:
`MAGNETOMETER_ALERTS_INI_PATH=/path/to/alerts.ini`

### Configure which levels trigger email

Set `MAGNETOMETER_EMAIL_ALERT_LEVELS` as a comma-separated list:

* `RED`
* `RED,AMBER`
* `RED,AMBER,YELLOW`

### Configure SMTP and recipients

You can set SMTP/email values in the `.ini` file, or by environment variables.
Environment variables take precedence if both are set.

Available environment variables are:

* `MAGNETOMETER_SMTP_HOST` (required)
* `MAGNETOMETER_SMTP_PORT` (default `587`)
* `MAGNETOMETER_SMTP_USERNAME` (optional)
* `MAGNETOMETER_SMTP_PASSWORD` (optional)
* `MAGNETOMETER_SMTP_STARTTLS` (`true` by default)
* `MAGNETOMETER_SMTP_SSL` (`false` by default)
* `MAGNETOMETER_EMAIL_FROM` (required)
* `MAGNETOMETER_EMAIL_TO` (required, comma-separated for multiple recipients)
* `MAGNETOMETER_EMAIL_ATTACH_PLOT` (`true` by default)
* `MAGNETOMETER_WEB_URL` (optional, included in email body)

### Notes

* Alert state is stored in `data/alerts/alert-state.json`
* Rolling status is read from `data/status/current.json`
* If `RollingActivity.png` exists, it is attached to the alert email
* Alert evaluator config precedence is: environment variable -> `.ini` file -> built-in default

### Regenerate a chosen Activity date (quick local test mode)

You can regenerate the hourly Activity plot for any date without storing an archive copy by default:

```
/bin/bash /home/pi/UKRAA_Magnetometer/scripts/testActivityPlotACM0.sh YYYY-MM-DD
```

This updates only:

* `/home/pi/UKRAA_Magnetometer/temp/Activity.png`

To also write the dated archive file in `plots/Activity/`, add `--archive`:

```
/bin/bash /home/pi/UKRAA_Magnetometer/scripts/testActivityPlotACM0.sh YYYY-MM-DD --archive
```

### Send a one-off SMTP test email

To verify SMTP settings without waiting for a threshold transition, run:

```
/bin/bash /home/pi/UKRAA_Magnetometer/scripts/testAlertEmailACM0.sh
```

Or run the Python script directly:

```
/usr/bin/python3 /home/pi/UKRAA_Magnetometer/scripts/EvaluateAlertsACM0.py --test-email
```

The test email does not update transition state, so normal alert logic is unaffected.

### Optional daily heartbeat email

You can enable a once-per-day summary email so you know the system is alive even when no threshold transition occurs.

In `alerts.ini`:

```
[heartbeat]
enabled = true
hour_utc = 9
to =
attach_plot = false
include_thresholds = false
message = This is a daily health-check email to confirm the magnetometer alert pipeline is running.
```

Notes:

* `hour_utc` is the first UTC hour of the day when the heartbeat can send.
* Only one heartbeat attempt is made per UTC day (success or failure), to avoid retry spam every 5 minutes.
* If `heartbeat.to` is blank, it uses `[email] to`.
* Set `heartbeat.include_thresholds = false` to omit the threshold values from the heartbeat.
* `heartbeat.message` controls the closing message; leave it blank to omit that line.

Environment variable overrides are also available:

* `MAGNETOMETER_HEARTBEAT_ENABLED`
* `MAGNETOMETER_HEARTBEAT_HOUR_UTC`
* `MAGNETOMETER_HEARTBEAT_TO`
* `MAGNETOMETER_HEARTBEAT_ATTACH_PLOT`
* `MAGNETOMETER_HEARTBEAT_INCLUDE_THRESHOLDS`
* `MAGNETOMETER_HEARTBEAT_MESSAGE`

### Send a one-off heartbeat test email immediately

To verify heartbeat email delivery without waiting for `heartbeat.hour_utc`, run:

```
/bin/bash /home/pi/UKRAA_Magnetometer/scripts/testHeartbeatEmailACM0.sh
```

Or run the Python script directly:

```
/usr/bin/python3 /home/pi/UKRAA_Magnetometer/scripts/EvaluateAlertsACM0.py --test-heartbeat
```

This immediate heartbeat test does not update daily heartbeat schedule/state tracking.
