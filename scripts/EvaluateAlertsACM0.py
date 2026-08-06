#!/usr/bin/env python3

import argparse
import configparser
import datetime
import json
import os
import smtplib
from email.message import EmailMessage

from magnetometer_common import ensure_directory
from magnetometer_common import get_base_path
from magnetometer_common import utc_now

LEVEL_RANK = {
    'unknown': -1,
    'quiet': 0,
    'yellow': 1,
    'amber': 2,
    'red': 3,
}


def log_msg(message):
    print(datetime.datetime.strftime(datetime.datetime.now(), '%Y-%m-%d %H:%M:%S'),
          ':',
          'EvaluateAlertsACM0.py    :',
          message)


def build_status_json_path(base_path):
    return os.path.join(base_path, 'data', 'status', 'current.json')


def build_alert_state_path(base_path):
    return os.path.join(base_path, 'data', 'alerts', 'alert-state.json')


def build_activity_plot_path(base_path):
    return os.path.join(base_path, 'temp', 'rolling', 'RollingActivity.png')


def build_default_config_path(base_path):
    return os.path.join(base_path, 'config', 'alerts.ini')


def load_config_parser(config_path):
    parser = configparser.ConfigParser()
    if os.path.exists(config_path):
        with open(config_path, mode='r', encoding='UTF-8') as config_file:
            # Strip optional BOM so configparser can parse files saved by different editors.
            config_text = config_file.read().lstrip('\ufeff')
            parser.read_string(config_text)

    return parser


def get_config_value(parser, env_name, section, option, default_value):
    env_value = os.environ.get(env_name)
    if env_value is not None:
        return env_value.strip()

    if parser.has_section(section) and parser.has_option(section, option):
        return parser.get(section, option).strip()

    return default_value


def load_json_or_default(path, default_value):
    if not os.path.exists(path):
        return default_value

    with open(path, mode='r', encoding='utf-8-sig') as json_file:
        return json.load(json_file)


def build_default_status():
    return {
        'generated_at_utc': utc_now().replace(microsecond=0).isoformat(),
        'latest_processed_minute_utc': 'unknown',
        'latest_sample_time_utc': 'unknown',
        'latest_activity_nt': None,
        'alert_level': 'unknown',
        'is_stale': True,
        'yellow_threshold_nt': 50,
        'amber_threshold_nt': 100,
        'red_threshold_nt': 200,
        'detector_name': 'unknown',
    }


def parse_level_list(levels_text):
    result = []
    for level in levels_text.split(','):
        normalized = level.strip().lower()
        if normalized in ('yellow', 'amber', 'red') and normalized not in result:
            result.append(normalized)

    return result


def get_configured_levels(parser):
    levels_text = get_config_value(
        parser,
        'MAGNETOMETER_EMAIL_ALERT_LEVELS',
        'alerts',
        'email_alert_levels',
        'RED,AMBER,YELLOW')
    configured = parse_level_list(levels_text)
    if configured:
        return configured

    return ['red']


def parse_bool(value, default_value):
    if value is None:
        return default_value

    return value.strip().lower() in ('1', 'true', 'yes', 'y', 'on')


def parse_int(value, default_value, minimum_value=None, maximum_value=None):
    try:
        parsed = int(value)
    except (TypeError, ValueError):
        return default_value

    if minimum_value is not None and parsed < minimum_value:
        return minimum_value

    if maximum_value is not None and parsed > maximum_value:
        return maximum_value

    return parsed


def build_settings(base_path):
    config_path = os.environ.get('MAGNETOMETER_ALERTS_INI_PATH', '').strip()
    if not config_path:
        config_path = build_default_config_path(base_path)

    parser = load_config_parser(config_path)

    smtp_port_text = get_config_value(
        parser,
        'MAGNETOMETER_SMTP_PORT',
        'smtp',
        'port',
        '587')
    try:
        smtp_port = int(smtp_port_text)
    except ValueError:
        smtp_port = 587

    settings = {
        'config_path': config_path,
        'configured_levels': get_configured_levels(parser),
        'smtp_host': get_config_value(parser, 'MAGNETOMETER_SMTP_HOST', 'smtp', 'host', ''),
        'smtp_port': smtp_port,
        'smtp_user': get_config_value(parser, 'MAGNETOMETER_SMTP_USERNAME', 'smtp', 'username', ''),
        'smtp_password': get_config_value(parser, 'MAGNETOMETER_SMTP_PASSWORD', 'smtp', 'password', ''),
        'smtp_ssl': parse_bool(
            get_config_value(parser, 'MAGNETOMETER_SMTP_SSL', 'smtp', 'ssl', 'false'),
            False),
        'smtp_starttls': parse_bool(
            get_config_value(parser, 'MAGNETOMETER_SMTP_STARTTLS', 'smtp', 'starttls', 'true'),
            True),
        'email_from': get_config_value(parser, 'MAGNETOMETER_EMAIL_FROM', 'email', 'from', ''),
        'email_to': get_config_value(parser, 'MAGNETOMETER_EMAIL_TO', 'email', 'to', ''),
        'email_attach_plot': parse_bool(
            get_config_value(parser, 'MAGNETOMETER_EMAIL_ATTACH_PLOT', 'email', 'attach_plot', 'true'),
            True),
        'web_url': get_config_value(parser, 'MAGNETOMETER_WEB_URL', 'web', 'url', ''),
        'heartbeat_enabled': parse_bool(
            get_config_value(parser, 'MAGNETOMETER_HEARTBEAT_ENABLED', 'heartbeat', 'enabled', 'false'),
            False),
        'heartbeat_hour_utc': parse_int(
            get_config_value(parser, 'MAGNETOMETER_HEARTBEAT_HOUR_UTC', 'heartbeat', 'hour_utc', '9'),
            9,
            minimum_value=0,
            maximum_value=23),
        'heartbeat_attach_plot': parse_bool(
            get_config_value(parser, 'MAGNETOMETER_HEARTBEAT_ATTACH_PLOT', 'heartbeat', 'attach_plot', 'false'),
            False),
        'heartbeat_to': get_config_value(parser, 'MAGNETOMETER_HEARTBEAT_TO', 'heartbeat', 'to', ''),
    }

    return settings


def should_send_alert(status, previous_state, configured_levels):
    if status.get('is_stale', True):
        return False

    current_level = (status.get('alert_level') or 'unknown').lower()
    if current_level not in configured_levels:
        return False

    current_rank = LEVEL_RANK.get(current_level, -1)
    previous_rank = LEVEL_RANK.get((previous_state.get('last_level') or 'unknown').lower(), -1)
    last_email_level = (previous_state.get('last_email_level') or 'unknown').lower()

    # Send when crossing upward into a configured level.
    if current_rank > previous_rank:
        return True

    # Retry when the current level has not yet produced a successful email.
    if current_level != last_email_level:
        return True

    return False


def build_email_message(status, previous_state, configured_levels, web_url):
    current_level = (status.get('alert_level') or 'unknown').upper()
    previous_level = (previous_state.get('last_level') or 'unknown').upper()
    latest_activity = status.get('latest_activity_nt')

    activity_text = 'unknown'
    if latest_activity is not None:
        activity_text = f'{latest_activity:.1f} nT'

    subject = f'[UKRAA Magnetometer] {current_level} alert - {activity_text}'

    lines = [
        'UKRAA Magnetometer threshold transition alert',
        '',
        f'Current level: {current_level}',
        f'Previous level: {previous_level}',
        f'Latest activity: {activity_text}',
        f'Latest sample time (UTC): {status.get("latest_sample_time_utc", "unknown")}',
        f'Latest processed minute (UTC): {status.get("latest_processed_minute_utc", "unknown")}',
        f'Detector: {status.get("detector_name", "unknown")}',
        '',
        'AuroraWatch-aligned thresholds used:',
        f'  Yellow: {status.get("yellow_threshold_nt", "unknown")} nT',
        f'  Amber: {status.get("amber_threshold_nt", "unknown")} nT',
        f'  Red: {status.get("red_threshold_nt", "unknown")} nT',
        '',
        f'Configured email levels: {", ".join(level.upper() for level in configured_levels)}',
    ]

    if web_url:
        lines.extend(['', f'Web page: {web_url}'])

    lines.extend([
        '',
        'A copy of the rolling activity plot is attached when available.',
    ])

    return subject, '\n'.join(lines)


def build_test_email_message(settings, status):
    configured_levels = settings['configured_levels']
    web_url = settings['web_url']

    latest_activity = status.get('latest_activity_nt')
    activity_text = 'unknown'
    if latest_activity is not None:
        activity_text = f'{latest_activity:.1f} nT'

    subject = f'[UKRAA Magnetometer] TEST email - {activity_text}'

    lines = [
        'This is a UKRAA Magnetometer SMTP test email.',
        '',
        'If you received this message, your SMTP settings are working.',
        '',
        f'Configured levels: {", ".join(level.upper() for level in configured_levels)}',
        f'Latest alert level in status file: {(status.get("alert_level") or "unknown").upper()}',
        f'Latest activity: {activity_text}',
        f'Latest sample time (UTC): {status.get("latest_sample_time_utc", "unknown")}',
        f'Detector: {status.get("detector_name", "unknown")}',
        '',
        'Thresholds in use:',
        f'  Yellow: {status.get("yellow_threshold_nt", "unknown")} nT',
        f'  Amber: {status.get("amber_threshold_nt", "unknown")} nT',
        f'  Red: {status.get("red_threshold_nt", "unknown")} nT',
    ]

    if web_url:
        lines.extend(['', f'Web page: {web_url}'])

    lines.extend([
        '',
        'Rolling activity plot is attached when available and enabled.',
    ])

    return subject, '\n'.join(lines)


def build_heartbeat_email_message(status, settings, now_utc):
    latest_activity = status.get('latest_activity_nt')
    activity_text = 'unknown'
    if latest_activity is not None:
        activity_text = f'{latest_activity:.1f} nT'

    level_text = (status.get('alert_level') or 'unknown').upper()
    subject = f'[UKRAA Magnetometer] Daily heartbeat - {level_text} - {activity_text}'

    lines = [
        'UKRAA Magnetometer daily heartbeat',
        '',
        f'Sent at (UTC): {now_utc.isoformat()}',
        f'Current alert level: {level_text}',
        f'Latest activity: {activity_text}',
        f'Latest sample time (UTC): {status.get("latest_sample_time_utc", "unknown")}',
        f'Latest processed minute (UTC): {status.get("latest_processed_minute_utc", "unknown")}',
        f'Stale status: {status.get("is_stale", True)}',
        f'Detector: {status.get("detector_name", "unknown")}',
        '',
        'Thresholds in use:',
        f'  Yellow: {status.get("yellow_threshold_nt", "unknown")} nT',
        f'  Amber: {status.get("amber_threshold_nt", "unknown")} nT',
        f'  Red: {status.get("red_threshold_nt", "unknown")} nT',
    ]

    web_url = settings.get('web_url', '')
    if web_url:
        lines.extend(['', f'Web page: {web_url}'])

    lines.extend([
        '',
        'This is a daily health-check email to confirm the magnetometer alert pipeline is running.',
    ])

    return subject, '\n'.join(lines)


def build_heartbeat_mail_settings(settings):
    heartbeat_settings = dict(settings)
    heartbeat_settings['email_attach_plot'] = settings['heartbeat_attach_plot']

    heartbeat_to = settings['heartbeat_to'].strip()
    if heartbeat_to:
        heartbeat_settings['email_to'] = heartbeat_to

    return heartbeat_settings


def maybe_send_daily_heartbeat(status, previous_state, settings, activity_plot_path):
    if not settings['heartbeat_enabled']:
        return {
            'attempted': False,
            'sent': False,
            'error': '',
            'attempt_date_utc': previous_state.get('last_heartbeat_attempt_date_utc'),
            'attempt_utc': previous_state.get('last_heartbeat_attempt_utc'),
            'sent_date_utc': previous_state.get('last_heartbeat_sent_date_utc'),
            'sent_utc': previous_state.get('last_heartbeat_sent_utc'),
        }

    now_utc = utc_now().replace(microsecond=0)
    today_utc = now_utc.date().isoformat()

    if now_utc.hour < settings['heartbeat_hour_utc']:
        return {
            'attempted': False,
            'sent': False,
            'error': '',
            'attempt_date_utc': previous_state.get('last_heartbeat_attempt_date_utc'),
            'attempt_utc': previous_state.get('last_heartbeat_attempt_utc'),
            'sent_date_utc': previous_state.get('last_heartbeat_sent_date_utc'),
            'sent_utc': previous_state.get('last_heartbeat_sent_utc'),
        }

    last_attempt_date = previous_state.get('last_heartbeat_attempt_date_utc')
    if last_attempt_date == today_utc:
        return {
            'attempted': False,
            'sent': False,
            'error': previous_state.get('last_heartbeat_error', ''),
            'attempt_date_utc': previous_state.get('last_heartbeat_attempt_date_utc'),
            'attempt_utc': previous_state.get('last_heartbeat_attempt_utc'),
            'sent_date_utc': previous_state.get('last_heartbeat_sent_date_utc'),
            'sent_utc': previous_state.get('last_heartbeat_sent_utc'),
        }

    subject, body = build_heartbeat_email_message(status, settings, now_utc)
    success, error_text = send_email(
        build_heartbeat_mail_settings(settings),
        subject,
        body,
        activity_plot_path)

    if success:
        log_msg('Daily heartbeat email sent successfully')
    else:
        log_msg('Daily heartbeat email failed: ' + error_text)

    return {
        'attempted': True,
        'sent': success,
        'error': '' if success else error_text,
        'attempt_date_utc': today_utc,
        'attempt_utc': now_utc.isoformat(),
        'sent_date_utc': today_utc if success else previous_state.get('last_heartbeat_sent_date_utc'),
        'sent_utc': now_utc.isoformat() if success else previous_state.get('last_heartbeat_sent_utc'),
    }


def send_email(settings, subject, body, attachment_path):
    smtp_host = settings['smtp_host']
    smtp_port = settings['smtp_port']
    smtp_user = settings['smtp_user']
    smtp_password = settings['smtp_password']
    smtp_from = settings['email_from']
    smtp_to = settings['email_to']
    smtp_ssl = settings['smtp_ssl']
    smtp_starttls = settings['smtp_starttls']
    attach_plot = settings['email_attach_plot']

    if not (smtp_host and smtp_from and smtp_to):
        return False, 'SMTP configuration incomplete (need host, from, to)'

    recipients = [address.strip() for address in smtp_to.split(',') if address.strip()]
    if not recipients:
        return False, 'No valid recipient addresses found'

    msg = EmailMessage()
    msg['Subject'] = subject
    msg['From'] = smtp_from
    msg['To'] = ', '.join(recipients)
    msg.set_content(body)

    if attach_plot and os.path.exists(attachment_path):
        with open(attachment_path, mode='rb') as image_file:
            image_data = image_file.read()
            msg.add_attachment(image_data,
                               maintype='image',
                               subtype='png',
                               filename='RollingActivity.png')

    try:
        if smtp_ssl:
            with smtplib.SMTP_SSL(smtp_host, smtp_port, timeout=30) as server:
                if smtp_user:
                    server.login(smtp_user, smtp_password)
                server.send_message(msg)
        else:
            with smtplib.SMTP(smtp_host, smtp_port, timeout=30) as server:
                if smtp_starttls:
                    server.starttls()
                if smtp_user:
                    server.login(smtp_user, smtp_password)
                server.send_message(msg)
    except Exception as exc:
        return False, str(exc)

    return True, ''


def save_state(path, state):
    ensure_directory(os.path.dirname(path))
    with open(path, mode='w', encoding='UTF-8') as state_file:
        json.dump(state, state_file, indent=2)
        state_file.write('\n')


def parse_args():
    parser = argparse.ArgumentParser(
        description='Evaluate rolling geomagnetic alerts and send SMTP notifications.')
    parser.add_argument(
        '--test-email',
        action='store_true',
        help='Send a one-off SMTP test email and exit. Does not modify alert-state tracking.')
    parser.add_argument(
        '--test-heartbeat',
        action='store_true',
        help='Send a one-off heartbeat email immediately and exit. Ignores schedule/state gating.')

    return parser.parse_args()


def main():
    args = parse_args()

    base_path = get_base_path()
    status_path = build_status_json_path(base_path)
    state_path = build_alert_state_path(base_path)
    activity_plot_path = build_activity_plot_path(base_path)
    settings = build_settings(base_path)
    configured_levels = settings['configured_levels']
    web_url = settings['web_url']

    status = load_json_or_default(status_path, None)

    if args.test_email:
        if status is None:
            status = build_default_status()
            log_msg('No rolling status JSON found; sending test email with default status values')

        subject, body = build_test_email_message(settings, status)
        success, error_text = send_email(settings, subject, body, activity_plot_path)
        if success:
            log_msg('SMTP test email sent successfully')
            return 0

        log_msg('SMTP test email failed: ' + error_text)
        return 2

    if args.test_heartbeat:
        if status is None:
            status = build_default_status()
            log_msg('No rolling status JSON found; sending heartbeat test email with default status values')

        heartbeat_settings = build_heartbeat_mail_settings(settings)
        subject, body = build_heartbeat_email_message(status, settings, utc_now().replace(microsecond=0))
        success, error_text = send_email(heartbeat_settings, subject, body, activity_plot_path)
        if success:
            log_msg('Heartbeat test email sent successfully')
            return 0

        log_msg('Heartbeat test email failed: ' + error_text)
        return 2

    if status is None:
        log_msg('No rolling status JSON found; skipping alert evaluation')
        return 0

    previous_state = load_json_or_default(state_path, {})
    current_level = (status.get('alert_level') or 'unknown').lower()
    previous_level = (previous_state.get('last_level') or 'unknown').lower()

    next_state = {
        'last_run_utc': utc_now().replace(microsecond=0).isoformat(),
        'last_level': current_level,
        'last_activity_nt': status.get('latest_activity_nt'),
        'last_sample_time_utc': status.get('latest_sample_time_utc'),
        'last_email_level': previous_state.get('last_email_level', 'unknown'),
        'last_email_sent_utc': previous_state.get('last_email_sent_utc'),
        'last_email_error': previous_state.get('last_email_error', ''),
        'configured_levels': configured_levels,
        'config_path': settings['config_path'],
        'last_heartbeat_attempt_date_utc': previous_state.get('last_heartbeat_attempt_date_utc'),
        'last_heartbeat_attempt_utc': previous_state.get('last_heartbeat_attempt_utc'),
        'last_heartbeat_sent_date_utc': previous_state.get('last_heartbeat_sent_date_utc'),
        'last_heartbeat_sent_utc': previous_state.get('last_heartbeat_sent_utc'),
        'last_heartbeat_error': previous_state.get('last_heartbeat_error', ''),
    }

    heartbeat_result = maybe_send_daily_heartbeat(status, previous_state, settings, activity_plot_path)
    next_state['last_heartbeat_attempt_date_utc'] = heartbeat_result['attempt_date_utc']
    next_state['last_heartbeat_attempt_utc'] = heartbeat_result['attempt_utc']
    next_state['last_heartbeat_sent_date_utc'] = heartbeat_result['sent_date_utc']
    next_state['last_heartbeat_sent_utc'] = heartbeat_result['sent_utc']
    next_state['last_heartbeat_error'] = heartbeat_result['error']

    should_send = should_send_alert(status, previous_state, configured_levels)

    if not should_send:
        if LEVEL_RANK.get(current_level, -1) <= 0:
            next_state['last_email_level'] = current_level
        save_state(state_path, next_state)
        log_msg(f'No email alert required (level {previous_level.upper()} -> {current_level.upper()})')
        return 0

    subject, body = build_email_message(status, previous_state, configured_levels, web_url)
    success, error_text = send_email(settings, subject, body, activity_plot_path)

    if success:
        next_state['last_email_level'] = current_level
        next_state['last_email_sent_utc'] = utc_now().replace(microsecond=0).isoformat()
        next_state['last_email_error'] = ''
        save_state(state_path, next_state)
        log_msg(f'Alert email sent for transition {previous_level.upper()} -> {current_level.upper()}')
        return 0

    next_state['last_email_error'] = error_text
    save_state(state_path, next_state)
    log_msg(f'Alert email failed for level {current_level.upper()} : {error_text}')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
