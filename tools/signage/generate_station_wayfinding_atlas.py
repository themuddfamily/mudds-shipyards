#!/usr/bin/env python3
"""Regenerate the station wayfinding sign atlas using only the standard library.

The label table is read from `SIGN_LABELS` in
`scripts/world/station_wayfinding_signage.gd`, which is the single source of
truth: the row index there is the atlas cell index here. Lettering reuses the
project's own font-free engineering alphabet from `generate_ship_markings.py`.

Layout (must match the GDScript constants): a 1024 x 1024 SVG of two columns of
512 x 64 cells. Cells 0..29 are available for labels (unused cells stay blank), cell 30 holds the up-pointing
arrow in its first 64 x 64 square, cell 31 is a blank plate for backing and
posts. Every plate is dark (#0e171e) with pale (#eef3f1) lettering, so the sign
reads at high contrast; the accent colour always accompanies a unique icon
silhouette and is never the only cue.
"""
from math import cos, pi, sin
from pathlib import Path
import re
import sys

sys.dont_write_bytecode = True

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
from generate_ship_markings import GLYPHS  # noqa: E402

SOURCE = ROOT / 'scripts/world/station_wayfinding_signage.gd'
OUT = ROOT / 'assets/signage/station_wayfinding_atlas.svg'

ATLAS = 1024
COLUMNS = 2
CELL_W = 512
CELL_H = 64
ARROW_CELL = 30
BLANK_CELL = 31
PLATE = '#0e171e'
INK = '#eef3f1'
TEXT_LEFT = 72
TEXT_RIGHT_PAD = 24
MAX_TEXT_HEIGHT = 32

LABEL_LINE = re.compile(r'^\s*\[&"([a-z0-9_]+)", "([A-Z0-9 \-/.]+)", &"([a-z]+)", "(#[0-9a-f]{6})"\],\s*$')


def read_labels():
    labels = []
    inside = False
    for line in SOURCE.read_text().splitlines():
        if line.startswith('const SIGN_LABELS'):
            inside = True
            continue
        if inside:
            if line.startswith(']'):
                break
            match = LABEL_LINE.match(line)
            if not match:
                raise SystemExit(f'unparseable SIGN_LABELS line: {line!r}')
            labels.append(match.groups())
    if not labels or len(labels) > ARROW_CELL:
        raise SystemExit(f'expected 1..{ARROW_CELL} labels, found {len(labels)}')
    return labels


def cell_origin(index):
    return (index % COLUMNS) * CELL_W, (index // COLUMNS) * CELL_H


def polygon(cx, cy, radius, sides, rotation):
    points = []
    for i in range(sides):
        a = rotation + 2 * pi * i / sides
        points.append(f'{cx + radius * cos(a):.2f},{cy + radius * sin(a):.2f}')
    return ' '.join(points)


def icon(shape, cx, cy, color):
    r = 17
    edge = f'stroke="{INK}" stroke-width="2" stroke-linejoin="round"'
    if shape == 'ring':
        return f'<circle cx="{cx}" cy="{cy}" r="{r - 3}" fill="none" stroke="{color}" stroke-width="6"/>'
    if shape == 'disc':
        return f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{color}" {edge}/>'
    if shape == 'square':
        s = r * 1.6
        return f'<rect x="{cx - s / 2:.2f}" y="{cy - s / 2:.2f}" width="{s:.2f}" height="{s:.2f}" fill="{color}" {edge}/>'
    if shape == 'triangle':
        return f'<polygon points="{polygon(cx, cy + 3, r + 2, 3, -pi / 2)}" fill="{color}" {edge}/>'
    if shape == 'diamond':
        return f'<polygon points="{polygon(cx, cy, r + 1, 4, -pi / 2)}" fill="{color}" {edge}/>'
    if shape == 'hexagon':
        return f'<polygon points="{polygon(cx, cy, r, 6, 0)}" fill="{color}" {edge}/>'
    if shape == 'pentagon':
        return f'<polygon points="{polygon(cx, cy + 1, r, 5, -pi / 2)}" fill="{color}" {edge}/>'
    if shape == 'plus':
        w, l = 11, 34
        return (f'<path d="M{cx - w / 2} {cy - l / 2}h{w}v{(l - w) / 2}h{(l - w) / 2}v{w}h{-(l - w) / 2}'
                f'v{(l - w) / 2}h{-w}v{-(l - w) / 2}h{-(l - w) / 2}v{-w}h{(l - w) / 2}z" fill="{color}" {edge}/>')
    if shape == 'chevron':
        return (f'<path d="M{cx - 15} {cy - 15}L{cx + 3} {cy - 15}L{cx + 17} {cy}L{cx + 3} {cy + 15}'
                f'L{cx - 15} {cy + 15}L{cx - 1} {cy}Z" fill="{color}" {edge}/>')
    raise SystemExit(f'unknown icon shape {shape}')


def lettering(text, x, cy, max_width):
    advance_units = 8.8
    width_units = len(text) * advance_units - 2.8
    height = min(MAX_TEXT_HEIGHT, max_width / width_units * 10)
    scale = height / 10
    y = cy - height / 2
    paths = []
    for i, letter in enumerate(text):
        if letter != ' ':
            paths.append(f'<path transform="translate({x + i * advance_units * scale:.2f} {y:.2f}) scale({scale:.4f})" d="{GLYPHS[letter]}"/>')
    return (f'<g fill="none" stroke="{INK}" stroke-width="1.05" stroke-linejoin="round" stroke-linecap="round">'
            + ''.join(paths) + '</g>')


def label_cell(index, text, shape, accent):
    x, y = cell_origin(index)
    cy = y + CELL_H / 2
    return ''.join([
        f'<rect x="{x}" y="{y}" width="{CELL_W}" height="{CELL_H}" fill="{PLATE}"/>',
        f'<rect x="{x + 3}" y="{y + 3}" width="{CELL_W - 6}" height="{CELL_H - 6}" rx="6" fill="none" stroke="{INK}" stroke-width="2"/>',
        f'<rect x="{x + 8}" y="{y + 9}" width="5" height="{CELL_H - 18}" fill="{accent}"/>',
        icon(shape, x + 38, cy, accent),
        lettering(text, x + TEXT_LEFT, cy, CELL_W - TEXT_LEFT - TEXT_RIGHT_PAD),
    ])


def arrow_cell():
    x, y = cell_origin(ARROW_CELL)
    cx = x + CELL_H / 2
    # Up-pointing block arrow inside the first 64 x 64 square; the plate has no
    # border so the square can be rotated in 45 degree steps without a seam.
    head = f'M{cx} {y + 7}L{cx + 22} {y + 30}H{cx + 9}V{y + 57}H{cx - 9}V{y + 30}H{cx - 22}Z'
    return (f'<rect x="{x}" y="{y}" width="{CELL_W}" height="{CELL_H}" fill="{PLATE}"/>'
            f'<path d="{head}" fill="{INK}" stroke="{INK}" stroke-width="1.5" stroke-linejoin="round"/>')


def blank_cell():
    x, y = cell_origin(BLANK_CELL)
    return f'<rect x="{x}" y="{y}" width="{CELL_W}" height="{CELL_H}" fill="{PLATE}"/>'


def main():
    labels = read_labels()
    parts = [f'<rect width="{ATLAS}" height="{ATLAS}" fill="{PLATE}"/>']
    for index, (_key, text, shape, accent) in enumerate(labels):
        parts.append(label_cell(index, text, shape, accent))
    parts.append(arrow_cell())
    parts.append(blank_cell())
    svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{ATLAS}" height="{ATLAS}" viewBox="0 0 {ATLAS} {ATLAS}">'
           + ''.join(parts) + '</svg>\n')
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(svg)
    print(f'wrote {OUT.relative_to(ROOT)} ({len(labels)} labels)')


if __name__ == '__main__':
    main()
