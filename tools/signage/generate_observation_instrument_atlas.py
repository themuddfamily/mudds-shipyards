#!/usr/bin/env python3
"""Static Observation headings and diagrams; no simulated telemetry or fonts."""
from pathlib import Path
import re
import sys

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
from generate_ship_markings import GLYPHS

SOURCE = ROOT / 'scripts/world/observation_logistics_spur.gd'
OUT = ROOT / 'assets/signage/observation_instrument_atlas.svg'
INK = '#eef3f1'
PLATE = '#0e171e'


def heading(text):
    # Large engineering lettering with a consistent cap height on every plate.
    scale = 3.5
    advance = 8.8 * scale
    x = (512 - (len(text) * advance - 2.8 * scale)) / 2
    paths = [f'<path transform="translate({x + i * advance:.2f} 17) scale({scale})" d="{GLYPHS[c]}"/>'
             for i, c in enumerate(text) if c != ' ']
    return f'<g fill="none" stroke="{INK}" stroke-width="1.05" stroke-linejoin="round" stroke-linecap="round">' + ''.join(paths) + '</g>'


def main():
    match = re.search(r'const OBSERVATION_INSTRUMENT_HEADINGS := \[(.*?)\]', SOURCE.read_text())
    labels = re.findall(r'"([A-Z ]+)"', match.group(1))
    if labels != ['SECTOR VIEW', 'RANGE DISPLAY', 'LOGISTICS']:
        raise SystemExit('expected three instrument headings')
    # Abstract identity graphics: compass, range rings, manifest blocks. No
    # readings, values, progress bars, controls or purported working features.
    graphics = [
        '<circle cx="256" cy="92" r="22"/><path d="M256 66v52M230 92h52M244 104l24-24"/>',
        '<ellipse cx="256" cy="92" rx="42" ry="22"/><ellipse cx="256" cy="92" rx="22" ry="12"/><path d="M202 92h108"/>',
        '<rect x="213" y="73" width="26" height="35"/><rect x="247" y="73" width="26" height="35"/><rect x="281" y="73" width="18" height="35"/>',
    ]
    cells = []
    for i, text in enumerate(labels):
        cells.append(f'<g transform="translate(0 {i * 128})"><title>{text}</title>'
                     f'<rect x="5" y="5" width="502" height="118" rx="6" fill="{PLATE}" stroke="{INK}" stroke-width="2"/>'
                     + heading(text)
                     + f'<path d="M24 61h464" stroke="{INK}" stroke-width="1"/>'
                     + '<g fill="none" stroke="#8bd9de" stroke-width="3">' + graphics[i] + '</g></g>')
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text('<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">'
                   f'<rect width="512" height="512" fill="{PLATE}"/>' + ''.join(cells) + '</svg>\n')
    print(f'wrote {OUT.relative_to(ROOT)} (3 static instrument plates)')


if __name__ == '__main__':
    main()
