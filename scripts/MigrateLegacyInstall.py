#!/usr/bin/env python3

import argparse
import os
import shutil


LEGACY_SCRIPT_NAMES = (
    'backfillDailyPlotsACM0.sh',
    'checkDailyPublishHealthACM0.sh',
    'EvaluateAlertsACM0.py',
    'GetAlertThresholdsACM0.py',
    'GetDataRawACM0.py',
    'GetKpOptionsACM0.py',
    'GetPeriodPlotAvailabilityACM0.py',
    'GetPeriodPlotOptionsACM0.py',
    'GetPlotOptionsACM0.py',
    'MergeConfigACM0.py',
    'PlotDataActivityACM0.gp',
    'PlotDataBIACM0.gp',
    'PlotDataHDZACM0.gp',
    'PlotDataXYZACM0.gp',
    'PlotKpForecastACM0.gp',
    'PlotPeriodACM0.gp',
    'PlotPeriodBIACM0.gp',
    'PlotPeriodHDZACM0.gp',
    'PlotPeriodXYZACM0.gp',
    'PlotRollingActivityACM0.gp',
    'PlotRollingBIACM0.gp',
    'PlotRollingHDZACM0.gp',
    'PlotRollingXYZACM0.gp',
    'ProcessDailySummaryACM0.py',
    'ProcessDataHourACM0.py',
    'ProcessDataRawACM0.py',
    'ProcessRollingACM0.py',
    'UpdateKpForecastACM0.py',
    'uploadRemoteACM0.sh',
    'updateMagnetometerACM0.sh',
    'updateKpForecastACM0.sh',
    'testWebOptionalPlotsVisibilityACM0.sh',
    'testRemoteUploadACM0.sh',
    'testOptionalDailyPlotsACM0.sh',
    'testHeartbeatEmailACM0.sh',
    'testAlertEmailACM0.sh',
    'testActivityPlotACM0.sh',
    'showDashboardSummaryACM0.sh',
    'runPostUpdateChecksACM0.sh',
    'runCronJobACM0.sh',
    'publishWebACM0.sh',
    'processPeriodPlotsACM0.sh',
)

LEGACY_INSTALL_NAMES = (
    'PicoMagnetometerACM0.service',
    'crontabMagnetometerACM0.cron',
)


def migrate_legacy_logs(log_directory):
    migrated = []
    for suffix in ('', '-0', '-1', '-2'):
        old_path = os.path.join(
            log_directory, f'log-MagnetometerACM0{suffix}.txt')
        new_path = os.path.join(
            log_directory, f'log-Magnetometer{suffix}.txt')
        if not os.path.isfile(old_path):
            continue

        if os.path.exists(new_path):
            with open(old_path, mode='rb') as old_log:
                with open(new_path, mode='ab') as new_log:
                    shutil.copyfileobj(old_log, new_log)
            os.remove(old_path)
        else:
            os.replace(old_path, new_path)
        migrated.append(new_path)

    return migrated


def remove_legacy_files(base_path):
    removed = []
    for directory_name, file_names in (
            ('scripts', LEGACY_SCRIPT_NAMES),
            ('install', LEGACY_INSTALL_NAMES)):
        directory_path = os.path.join(base_path, directory_name)
        for file_name in file_names:
            file_path = os.path.join(directory_path, file_name)
            if os.path.isfile(file_path) or os.path.islink(file_path):
                os.remove(file_path)
                removed.append(file_path)

    return removed


def migrate_legacy_install(base_path):
    log_directory = os.path.join(base_path, 'logfiles')
    migrated_logs = migrate_legacy_logs(log_directory)
    removed_files = remove_legacy_files(base_path)
    return migrated_logs, removed_files


def main():
    argument_parser = argparse.ArgumentParser(
        description='Migrate legacy ACM0-named logs and files.')
    argument_parser.add_argument(
        '--base-path', default='/home/pi/UKRAA_Magnetometer')
    arguments = argument_parser.parse_args()

    migrated_logs, removed_files = migrate_legacy_install(arguments.base_path)
    print(f'Migrated {len(migrated_logs)} legacy log file(s).')
    print(f'Removed {len(removed_files)} obsolete ACM0-named file(s).')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())