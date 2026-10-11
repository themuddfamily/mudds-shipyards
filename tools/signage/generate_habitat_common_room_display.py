#!/usr/bin/env python3
"""Project-original static Habitat tabletop artwork; no fonts or live readings."""
from pathlib import Path
import re
import sys

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
from generate_ship_markings import GLYPHS

SOURCE = ROOT / 'scripts/world/habitat_spine.gd'
OUT = ROOT / 'assets/signage/habitat_common_room_display.svg'
INK = '#f0ede1'


def lettering(text, cx, y, height):
    scale = height / 10
    advance = 8.8 * scale
    left = cx - (len(text) * advance - 2.8 * scale) / 2
    paths = [f'<path transform="translate({left + i * advance:.2f} {y}) scale({scale:.3f})" d="{GLYPHS[c]}"/>'
             for i, c in enumerate(text) if c != ' ']
    return f'<g fill="none" stroke="{INK}" stroke-width="1.05" stroke-linecap="round" stroke-linejoin="round">' + ''.join(paths) + '</g>'


def main():
    match = re.search(r'const COMMON_ROOM_DISPLAY_LABELS := \[(.*?)\]', SOURCE.read_text())
    labels = re.findall(r'"([A-Z ]+)"', match.group(1))
    if labels != ['COMMON ROOM', 'REST', 'REFRESHMENTS']:
        raise SystemExit('expected the static common-room title and two purpose labels')
    parts = [
        '<rect width="512" height="256" fill="#102025"/>',
        '<rect x="7" y="7" width="498" height="242" rx="10" fill="none" stroke="#b3c8c6" stroke-width="2"/>',
        '<path d="M26 89h460M256 111v112" stroke="#b3c8c6" stroke-width="2"/>',
        lettering(labels[0], 256, 30, 40),
        # Chair and cup silhouettes repeat purpose in shape as well as text.
        '<g fill="none" stroke="#e4b982" stroke-width="6" stroke-linecap="round" stroke-linejoin="round">'
        '<path d="M112 122v39h44v-14M112 161v22M156 161v22M107 143h55"/>'
        '<path d="M354 129h48v37q0 14-24 14t-24-14zM402 136h10q17 12 0 24h-10M346 190h66"/>'
        '</g>',
        lettering(labels[1], 128, 208, 24),
        lettering(labels[2], 384, 208, 16),
    ]
    titles = ''.join(f'<title>{label}</title>' for label in labels)
    svg = '<svg xmlns="http://www.w3.org/2000/svg" width="512" height="256" viewBox="0 0 512 256">' + titles + ''.join(parts) + '</svg>\n'
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(svg)
    print(f'wrote {OUT.relative_to(ROOT)} (static common-room artwork)')


if __name__ == '__main__':
    main()
