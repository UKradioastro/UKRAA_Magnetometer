#!/usr/bin/env python3

import argparse
import csv
import datetime
import os
import subprocess
import sys

from magnetometer_common import get_base_path
from magnetometer_common import get_target_date
from space_weather import TIME_FORMAT
from space_weather import parse_time


FAMILY_PANELS = {
    'XYZ': [('X (nT)', 2, '#0000ff', 'X'), ('Y (nT)', 3, '#008000', 'Y'),
            ('Z (nT)', 4, '#cc0000', 'Z')],
    'HDZ': [('H (nT)', 7, '#0000ff', 'H'), ('D (deg)', 8, '#008000', 'D'),
            ('Z (nT)', 4, '#cc0000', 'Z')],
    'BI': [('B (nT)', 9, '#0000ff', 'B'), ('I (deg)', 10, '#008000', 'I')],
}
LEVEL_STYLES = [
    ('#2f6f44', 'Quiet'),
    ('#b8860b', 'G1'),
    ('#cc7000', 'G2'),
    ('#9f2d2d', 'G3'),
    ('#7f1d1d', 'G4'),
    ('#7a1f5c', 'G5'),
]
CME_COLOUR = '#1f5fbf'
PANEL_HEIGHT = 250
PERIOD_DAY_COUNTS = {'week': 7, 'month': 30, '3month': 90, '6month': 183, 'year': 365}


def _gp_quote(value):
    return "'{}'".format(value.replace('\\', '\\\\').replace("'", "\\'"))


def load_storms(path):
    storms = []
    if not os.path.isfile(path):
        return storms
    with open(path, mode='r', encoding='UTF-8', newline='') as storms_file:
        for row in csv.DictReader(storms_file):
            try:
                start = datetime.datetime.strptime(row['StormStart'], TIME_FORMAT)
                kp_value = float(row['MaxKp'])
                level = int(row['GLevel'])
            except (KeyError, TypeError, ValueError):
                continue
            storms.append({
                'start': start,
                'kp': kp_value,
                'level': max(0, min(5, level)),
                'cmes': [item for item in
                         (parse_time(text) for text in row.get('CMELaunches', '').split(';'))
                         if item],
                'shocks': [item for item in
                           (parse_time(text) for text in row.get('ShockArrivals', '').split(';'))
                           if item],
            })
    return storms


def has_kp_data(path, window_start, window_end):
    if not os.path.isfile(path):
        return False
    with open(path, mode='r', encoding='UTF-8', newline='') as kp_file:
        for row in csv.DictReader(kp_file):
            timestamp = parse_time(row.get('DateTime'))
            try:
                kp_value = float(row.get('Kp', row.get('MaxKp', 'nan')))
            except (TypeError, ValueError):
                continue
            if timestamp and window_start <= timestamp <= window_end and 0 <= kp_value <= 9:
                return True
    return False


def kp_text(kp_value):
    whole = int(round(kp_value))
    remainder = kp_value - whole
    if remainder > 0.1:
        return '{}+'.format(whole)
    if remainder < -0.1:
        return '{}-'.format(whole)
    return '{}o'.format(whole)


def gp_time(value):
    return 'strptime("%Y-%m-%d %H:%M:%S","{}")'.format(value.strftime(TIME_FORMAT))


def build_script(family, period_name, window_start, window_end, summary_path, kp_path,
                 kp_bar_seconds, storms, output_path, kp_available, label='Pico'):
    panels = FAMILY_PANELS[family]
    rows = len(panels) + 1
    lines = [
        'set terminal pngcairo background "#ffffff" enhanced font "DejaVuSansCondensed,10" '
        'size 960,{} rounded'.format(rows * PANEL_HEIGHT + 60),
        'set output {}'.format(_gp_quote(output_path)),
        'set datafile separator ","',
        'set xdata time',
        'set timefmt "%Y-%m-%d %H:%M:%S"',
        'set format x "{}"'.format('%d %b' if period_name in ('week', 'month') else '%b\\n%Y'),
        'set xrange ["{}":"{}"]'.format(window_start.strftime(TIME_FORMAT),
                                           window_end.strftime(TIME_FORMAT)),
        'set grid xtics ytics',
        'set lmargin 10',
        'set rmargin 10',
        'set ytics nomirror',
        'set key outside above center',
    ]

    visible_storms = [storm for storm in storms
                      if window_start <= storm['start'] <= window_end]
    for storm in visible_storms:
        colour = LEVEL_STYLES[storm['level']][0]
        lines.append('set arrow from first {0}, graph 0 to first {0}, graph 1 nohead dt 2 lw 1.2 '
                     'lc rgb "{1}" back'.format(gp_time(storm['start']), colour))

    title = '{} {} magnetic field with historical Kp and geomagnetic storms: {} to {}\\nDaily means'.format(
        label, family, window_start.date(), window_end.date())
    lines.append('set multiplot layout {},1 title "{}" font ",12"'.format(rows, title))
    for ylabel, column, colour, key_title in panels:
        lines.append('set ylabel "{}"'.format(ylabel))
        lines.append('plot {} using 1:{} with lines linewidth 1.2 linecolor rgb "{}" title "{}"'.format(
            _gp_quote(summary_path), column, colour, key_title))

    lines += [
        'set ylabel "Kp"',
        'set xlabel "Date (UTC)"',
        'set yrange [0:10.4]',
        'set ytics 0,1,9',
        'set boxwidth {} absolute'.format(int(kp_bar_seconds * 0.9)),
        'set style fill solid 0.85 noborder',
        'set key outside above center horizontal font ",8"',
        'set label "Kp: GFZ Potsdam (CC BY 4.0). Storms, CMEs and shocks: NASA CCMC DONKI" '
        'at screen 0.99, screen 0.012 right font ",7" textcolor rgb "#555555"',
    ]

    minimum_label_level = 3 if period_name in ('6month', 'year') else 0
    previous_start = None
    label_y = 9.9
    crowded_seconds = (window_end - window_start).total_seconds() / 25
    lines.append('set style textbox opaque noborder margins 1,1')
    for storm in visible_storms:
        if storm['level'] < minimum_label_level:
            continue
        if previous_start and (storm['start'] - previous_start).total_seconds() < crowded_seconds:
            label_y = 9.55 if label_y == 9.9 else 9.9
        else:
            label_y = 9.9
        previous_start = storm['start']
        storm_label = 'G{} {}'.format(storm['level'], kp_text(storm['kp']))
        lines.append('set label "{}" at first {}, first {} center front boxed font ",7" '
                     'textcolor rgb "{}"'.format(
                         storm_label, gp_time(storm['start']), label_y,
                         LEVEL_STYLES[storm['level']][0]))

    for storm in visible_storms:
        for launch in storm['cmes']:
            shown_launch = max(launch, window_start)
            lines.append('set arrow from first {}, first 9.2 to first {}, first 9.2 '
                         'head size screen 0.006,25 lw 1.2 lc rgb "{}" front'.format(
                             gp_time(shown_launch), gp_time(storm['start']), CME_COLOUR))
            if launch >= window_start:
                lines.append('set label "" at first {}, first 9.2 point pt 9 ps 0.9 '
                             'lc rgb "{}" front'.format(gp_time(launch), CME_COLOUR))
        for shock in storm['shocks']:
            if window_start <= shock <= window_end:
                lines.append('set label "" at first {}, first 9.2 point pt 7 ps 0.5 '
                             'lc rgb "#000000" front'.format(gp_time(shock)))

    if not kp_available:
        lines += [
            'set ylabel "Kp unavailable"',
            'set label "No historical Kp data available for this window" at graph 0.5, graph 0.5 '
            'center front textcolor rgb "#555555"',
            'plot 1/0 notitle, 1/0 with points pt 9 ps 0.9 lc rgb "{}" '
            'title "CME launch to storm", 1/0 with points pt 7 ps 0.5 lc rgb "#000000" '
            'title "Shock at Earth"'.format(CME_COLOUR),
            'unset label',
        ]
    else:
        plot_terms = []
        for level, (colour, key_title) in enumerate(LEVEL_STYLES):
            plot_terms.append('{} using 1:($3=={} ? $2 : 1/0) with boxes lc rgb "{}" title "{}"'.format(
                _gp_quote(kp_path), level, colour, key_title))
        plot_terms.append('1/0 with points pt 9 ps 0.9 lc rgb "{}" title "CME launch to storm"'.format(
            CME_COLOUR))
        plot_terms.append('1/0 with points pt 7 ps 0.5 lc rgb "#000000" title "Shock at Earth"')
        lines.append('plot ' + ', '.join(plot_terms))

    lines += ['unset multiplot', 'set output']
    return '\n'.join(lines) + '\n'


def parse_arguments():
    parser = argparse.ArgumentParser(description='Draw a Pico period plot with historical space weather.')
    parser.add_argument('--period', required=True, choices=PERIOD_DAY_COUNTS)
    parser.add_argument('--family', required=True, choices=FAMILY_PANELS)
    parser.add_argument('--target-date', type=datetime.date.fromisoformat)
    return parser.parse_args()


def main():
    arguments = parse_arguments()
    base_path = get_base_path()
    target_date = arguments.target_date or get_target_date()
    window_days = PERIOD_DAY_COUNTS[arguments.period]
    window_start = datetime.datetime.combine(
        target_date - datetime.timedelta(days=window_days - 1), datetime.time.min)
    window_end = datetime.datetime.combine(target_date, datetime.time(23, 59, 59))
    summary_path = os.path.join(base_path, 'data', 'daily', 'summary.csv')
    weather_paths = {
        'directory': os.path.join(base_path, 'data', 'spaceweather'),
        'kp': os.path.join(base_path, 'data', 'spaceweather',
                           'kp_daily.csv' if window_days > 31 else 'kp_3hour.csv'),
        'storms': os.path.join(base_path, 'data', 'spaceweather', 'storms.csv'),
    }
    if not os.path.isfile(summary_path):
        print('ERROR: daily summary missing: ' + summary_path, file=sys.stderr)
        return 1

    kp_bar_seconds = 86400 if window_days > 31 else 10800
    kp_available = has_kp_data(weather_paths['kp'], window_start, window_end)
    storms = load_storms(weather_paths['storms'])
    archive_directory = os.path.join(
        base_path, 'plots', arguments.period, arguments.family,
        target_date.strftime('%Y'), target_date.strftime('%Y-%m'))
    temp_directory = os.path.join(base_path, 'temp', 'periods', arguments.period)
    script_directory = os.path.join(base_path, 'temp', 'spaceweather')
    for directory in (archive_directory, temp_directory, script_directory):
        os.makedirs(directory, exist_ok=True)

    output_path = os.path.join(archive_directory, target_date.isoformat() + '.png')
    temp_path = os.path.join(temp_directory, arguments.family + '.png')
    script_path = os.path.join(script_directory, '{}_{}.gp'.format(
        arguments.period, arguments.family))
    script = build_script(
        arguments.family, arguments.period, window_start, window_end,
        summary_path, weather_paths['kp'], kp_bar_seconds, storms, output_path, kp_available)
    with open(script_path, mode='w', encoding='UTF-8', newline='\n') as script_file:
        script_file.write(script)

    try:
        result = subprocess.run(['gnuplot', script_path], capture_output=True, text=True)
    except FileNotFoundError:
        print('ERROR: gnuplot is not installed; script written to ' + script_path, file=sys.stderr)
        return 1
    if result.returncode != 0 or not os.path.isfile(output_path):
        print('ERROR: gnuplot failed: ' + result.stderr.strip(), file=sys.stderr)
        return 1

    with open(output_path, 'rb') as source_file, open(temp_path, 'wb') as target_file:
        target_file.write(source_file.read())
    os.chmod(output_path, 0o644)
    os.chmod(temp_path, 0o644)
    print('INFO: Plotted {} {} with {} Kp data'.format(
        arguments.period, arguments.family, 'available' if kp_available else 'unavailable'))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())