#!/usr/bin/env python3

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
          'EvaluateAlertsACM0.py :',
          message)


def build_status_json_path(base_path):
    return os.path.join(base_path, 'data', 'status', 'current.json')


def build_alert_state_path(base_path):
    return os.path.join(base_path, 'data', 'alerts', 'alert-state.json')


def build_activity_plot_path(base_path):
    return os.path.join(base_path, 'temp', 'rolling', 'RollingActivity.png')


def load_json_or_default(path, default_value):
    if not os.path.exists(path):
        return default_value

    with open(path, mode='r', encoding='UTF-8') as json_file:
        return json.load(json_file)


def parse_level_list(levels_text):
    result = []
    for level in levels_text.split(','):
        normalized = level.strip().lower()
        if normalized in ('yellow', 'amber', 'red') and normalized not in result:
            result.append(normalized)

    return result


def get_configured_levels():
    levels_text = os.environ.get('MAGNETOMETER_EMAIL_ALERT_LEVELS', 'RED,AMBER,YELLOW')
    configured = parse_level_list(levels_text)
    if configured:
        return configured

    return ['red']


def bool_from_env(name, default_value):
    raw = os.environ.get(name)
    if raw is None:
        return default_value

    return raw.strip().lower() in ('1', 'true', 'yes', 'y', 'on')


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


def send_email(subject, body, attachment_path):
    smtp_host = os.environ.get('MAGNETOMETER_SMTP_HOST', '').strip()
    smtp_port = int(os.environ.get('MAGNETOMETER_SMTP_PORT', '587'))
    smtp_user = os.environ.get('MAGNETOMETER_SMTP_USERNAME', '').strip()
    smtp_password = os.environ.get('MAGNETOMETER_SMTP_PASSWORD', '')
    smtp_from = os.environ.get('MAGNETOMETER_EMAIL_FROM', '').strip()
    smtp_to = os.environ.get('MAGNETOMETER_EMAIL_TO', '').strip()
    smtp_ssl = bool_from_env('MAGNETOMETER_SMTP_SSL', False)
    smtp_starttls = bool_from_env('MAGNETOMETER_SMTP_STARTTLS', True)
    attach_plot = bool_from_env('MAGNETOMETER_EMAIL_ATTACH_PLOT', True)

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


def main():
    base_path = get_base_path()
    status_path = build_status_json_path(base_path)
    state_path = build_alert_state_path(base_path)
    activity_plot_path = build_activity_plot_path(base_path)
    configured_levels = get_configured_levels()
    web_url = os.environ.get('MAGNETOMETER_WEB_URL', '').strip()

    status = load_json_or_default(status_path, None)
    if status is None:
        log_msg('No rolling status JSON found; skipping alert evaluation')
        return

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
    }

    should_send = should_send_alert(status, previous_state, configured_levels)

    if not should_send:
        if LEVEL_RANK.get(current_level, -1) <= 0:
            next_state['last_email_level'] = current_level
        save_state(state_path, next_state)
        log_msg(f'No email alert required (level {previous_level.upper()} -> {current_level.upper()})')
        return

    subject, body = build_email_message(status, previous_state, configured_levels, web_url)
    success, error_text = send_email(subject, body, activity_plot_path)

    if success:
        next_state['last_email_level'] = current_level
        next_state['last_email_sent_utc'] = utc_now().replace(microsecond=0).isoformat()
        next_state['last_email_error'] = ''
        save_state(state_path, next_state)
        log_msg(f'Alert email sent for transition {previous_level.upper()} -> {current_level.upper()}')
    else:
        next_state['last_email_error'] = error_text
        save_state(state_path, next_state)
        log_msg(f'Alert email failed for level {current_level.upper()} : {error_text}')


if __name__ == '__main__':
    main()
