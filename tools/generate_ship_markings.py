#!/usr/bin/env python3
"""Regenerate original, font-free hull paint SVGs using only the standard library.

Letterforms are project-authored continuous geometric pen paths, not a font or
seven-segment display. SVGs use simple paths and flat colors for Godot import.
"""
from pathlib import Path

OUT = Path(__file__).resolve().parents[1] / 'assets/ships/markings'
INK = '#283139'
AMBER = '#be893a'
PALE = '#d9ddd6'
# Six-unit wide, ten-unit tall engineering alphabet. Curves soften the printing.
GLYPHS = {
'A': 'M0 10L2.3 0H3.7L6 10M1.1 6H4.9',
'B': 'M0 10V0H3.5Q6 0 6 2.5Q6 5 3.5 5H0M3.5 5Q6 5 6 7.5Q6 10 3.5 10H0',
'C': 'M6 1Q5 0 3 0Q0 0 0 3V7Q0 10 3 10Q5 10 6 9',
'D': 'M0 10V0H2.5Q6 0 6 4V6Q6 10 2.5 10Z',
'E': 'M6 0H0V10H6M0 5H4.7',
'F': 'M6 0H0V10M0 5H4.7',
'G': 'M6 1Q5 0 3 0Q0 0 0 3V7Q0 10 3 10Q5 10 6 9V5H3.5',
'H': 'M0 0V10M6 0V10M0 5H6',
'I': 'M0 0H6M3 0V10M0 10H6',
'J': 'M0 0H6V7Q6 10 3 10Q0 10 0 7',
'K': 'M0 0V10M6 0L0 6M2.5 3.5L6 10',
'L': 'M0 0V10H6',
'M': 'M0 10V0L3 5L6 0V10',
'N': 'M0 10V0L6 10V0',
'O': 'M3 0Q0 0 0 3V7Q0 10 3 10Q6 10 6 7V3Q6 0 3 0Z',
'P': 'M0 10V0H3.5Q6 0 6 2.5Q6 5 3.5 5H0',
'Q': 'M3 0Q0 0 0 3V7Q0 10 3 10Q6 10 6 7V3Q6 0 3 0ZM3.5 7L7 11',
'R': 'M0 10V0H3.5Q6 0 6 2.5Q6 5 3.5 5H0M3.2 5L6 10',
'S': 'M6 1Q5 0 3 0Q0 0 0 2.5Q0 4.5 3 5Q6 5.5 6 7.5Q6 10 3 10Q1 10 0 9',
'T': 'M0 0H6M3 0V10',
'U': 'M0 0V7Q0 10 3 10Q6 10 6 7V0',
'V': 'M0 0L2.5 10H3.5L6 0',
'W': 'M0 0L1 10H2L3 5L4 10H5L6 0',
'X': 'M0 0L6 10M6 0L0 10',
'Y': 'M0 0L3 5L6 0M3 5V10',
'Z': 'M0 0H6L0 10H6',
'0': 'M3 0Q0 0 0 3V7Q0 10 3 10Q6 10 6 7V3Q6 0 3 0ZM1 8L5 2',
'1': 'M1 2L3 0V10M0 10H6',
'2': 'M0 2Q0 0 3 0Q6 0 6 2.5Q6 4 4 5.5L0 9V10H6',
'3': 'M0 0H3Q6 0 6 2.5Q6 5 3 5H2M3 5Q6 5 6 7.5Q6 10 3 10H0',
'4': 'M4 10V0H3L0 6V7H6',
'5': 'M6 0H0V5H3Q6 5 6 7.5Q6 10 3 10H0',
'6': 'M6 0H3Q0 0 0 4V7Q0 10 3 10Q6 10 6 7.5Q6 5 3 5H0',
'7': 'M0 0H6L2 10',
'8': 'M3 5Q0 5 0 2.5Q0 0 3 0Q6 0 6 2.5Q6 5 3 5Q0 5 0 7.5Q0 10 3 10Q6 10 6 7.5Q6 5 3 5Z',
'9': 'M0 10H3Q6 10 6 6V3Q6 0 3 0Q0 0 0 2.5Q0 5 3 5H6',
'-': 'M1 5H5', '/': 'M0 10L6 0', '.': 'M3 9.6V10',
}


def lettering(label, x, y, height, color=INK, weight=.85, spacing=2.8):
    scale = height / 10
    paths = []
    for i, letter in enumerate(label):
        if letter != ' ':
            paths.append(f'<path transform="translate({x + i * (6 + spacing) * scale:g} {y:g}) scale({scale:g})" d="{GLYPHS[letter]}"/>')
    return f'<g fill="none" stroke="{color}" stroke-width="{weight}" stroke-linejoin="round" stroke-linecap="round">' + ''.join(paths) + '</g>'


def path(d, color=INK, width=3, fill='none'):
    return f'<path d="{d}" fill="{fill}" stroke="{color}" stroke-width="{width}" stroke-linejoin="round"/>'


def arrow(x, y, size=1, color=AMBER, height_scale=None):
    return f'<path transform="translate({x} {y}) scale({size} {size if height_scale is None else height_scale})" d="M0 15H72V0L104 28L72 56V41H0Z" fill="{color}"/>'


def write(name, content):
    (OUT / f'{name}.svg').write_text('<?xml version="1.0" encoding="UTF-8"?>\n<svg xmlns="http://www.w3.org/2000/svg" width="512" height="256" viewBox="0 0 512 256">\n' + '\n'.join(content) + '\n</svg>\n')


CRAFT = [
    ('torrent', 'TX-09', 'INTERCEPTOR'),
    ('arrow', 'AR-02', 'RECONNAISSANCE'),
    ('zenith', 'ZI-07', 'STRIKE INTERCEPTOR'),
    ('jovian', 'JV-14', 'LIGHT FREIGHT'),
    ('halyard', 'HY-06', 'CREW TRANSPORT'),
    ('bulwark', 'BW-08', 'ARMORED ESCORT'),
    ('cinder-interceptor', 'CI-03', 'INTERCEPTOR'),
    ('cinder-bomber', 'CB-12', 'STRIKE BOMBER'),
    ('cinder-cargo', 'CH-05', 'CARGO HAULER'),
    ('range', 'RN-21', 'RANGE TARGET'),
    ('skirmisher', 'SK-04', 'FAST ATTACK'),
    ('picket', 'PK-11', 'PATROL ESCORT'),
    ('courier', 'CR-17', 'EXPRESS COURIER'),
]


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for name, code, role in CRAFT:
        write(name, [
            path('M26 52V30H112M26 192V221H112', width=3),
            path('M37 29H44V54H37Z M50 29H57V54H50Z M63 29H70V54H63Z', AMBER, 0, AMBER),
            lettering('SHIPYARD / FLIGHT SYSTEMS', 145, 32, 11, weight=.8),
            lettering(code, 42, 79, 89, weight=1.05, spacing=3.3),
            path('M42 190H470', width=2),
            lettering(role, 144, 207, 13, weight=.85, spacing=2.3),
            lettering('SERVICE 24 / FLIGHT READY', 145, 236, 8, weight=.8),
            path('M472 74V168', AMBER, 5),
        ])
    write('intake', [
        lettering('CAUTION', 32, 29, 22, weight=1),
        lettering('INTAKE', 32, 72, 47, weight=1.05),
        arrow(359, 71, 1.05),
        lettering('KEEP APERTURE CLEAR', 32, 151, 15),
        path('M28 190H484M28 230H484', width=2),
        *[path(f'M{x} 227L{x+27} 193', AMBER, 12) for x in range(45, 465, 40)],
    ])
    write('service', [
        path('M44 24H468L488 44V212L468 232H44L24 212V44Z', width=3),
        path('M48 44H70M59 33V55M442 212H464M453 201V223', width=2),
        '<circle cx="59" cy="44" r="15" fill="none" stroke="#283139" stroke-width="2"/>',
        '<circle cx="453" cy="212" r="15" fill="none" stroke="#283139" stroke-width="2"/>',
        lettering('ISOLATE', 116, 48, 18, weight=.95),
        lettering('ACCESS', 83, 99, 44, weight=1),
        path('M83 168H427', width=2),
        lettering('DEPRESSURIZE BEFORE OPENING', 83, 185, 11, spacing=1.8),
        path('M379 37H416L398 67Z', AMBER, 2, AMBER),
    ])
    write('rescue', [
        lettering('RESCUE', 32, 30, 52, weight=1.1),
        arrow(39, 117, 2.65, height_scale=1.65),
        lettering('RELEASE', 346, 138, 14),
        lettering('PULL', 346, 166, 20),
        lettering('EMERGENCY CANOPY ACCESS', 32, 231, 11),
    ])
    write('exhaust', [
        path('M79 29L130 118H28Z', AMBER, 6),
        *[path(f'M{x} 98Q{x-9} 89 {x} 80Q{x+9} 71 {x} 62', width=3) for x in (61,79,97)],
        lettering('THERMAL', 157, 42, 26, weight=1),
        lettering('HAZARD', 157, 86, 26, weight=1),
        path('M30 141H482', width=2),
        lettering('KEEP CLEAR', 34, 166, 39, weight=1),
        lettering('HOT EXHAUST / NO STEP', 34, 231, 12),
    ])


if __name__ == '__main__':
    main()
