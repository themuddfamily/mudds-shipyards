#!/usr/bin/env python3
"""Validate an authored planetary streaming/floating-origin evidence record.

The record describes deterministic handoff evidence only; it never streams
scenes, moves nodes, or performs a floating-origin rebase.
"""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
from typing import Any

SCHEMA_VERSION = 1
MAX_CELLS = 512
MAX_REBASE_EVENTS = 128


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _vector(value: Any) -> bool:
    return isinstance(value, list) and len(value) == 3 and all(
        isinstance(item, (int, float)) and math.isfinite(item) for item in value
    )


def validate_manifest(value: Any, label: str = "manifest") -> list[str]:
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    for key in ("world_id", "unit_system"):
        if not _text(value.get(key)):
            errors.append(f"{label}.{key} is required")
    cell_size = value.get("cell_size_m")
    if not isinstance(cell_size, (int, float)) or not math.isfinite(cell_size) or cell_size <= 0:
        errors.append(f"{label}.cell_size_m must be a positive finite number")

    cells = value.get("cells")
    if not isinstance(cells, list) or not 1 <= len(cells) <= MAX_CELLS:
        errors.append(f"{label}.cells must contain 1..{MAX_CELLS} entries")
        cells = []
    seen_cells: set[tuple[int, int, int]] = set()
    for index, cell in enumerate(cells):
        if not isinstance(cell, dict) or not _text(cell.get("id")):
            errors.append(f"{label}.cells[{index}].id is required")
            continue
        coordinate = cell.get("coordinate")
        if not isinstance(coordinate, list) or len(coordinate) != 3 or not all(isinstance(item, int) and not isinstance(item, bool) for item in coordinate):
            errors.append(f"{label}.cells[{index}].coordinate must contain three integers")
            continue
        key = tuple(coordinate)
        if key in seen_cells:
            errors.append(f"{label}.cells coordinates must be unique")
        seen_cells.add(key)
        if cell.get("state") not in {"AUTHORED", "OPTIONAL"}:
            errors.append(f"{label}.cells[{index}].state is invalid")
        if not _text(cell.get("scene_path")) or not cell["scene_path"].startswith("res://"):
            errors.append(f"{label}.cells[{index}].scene_path must be a res:// path")

    events = value.get("rebase_events")
    if not isinstance(events, list) or len(events) > MAX_REBASE_EVENTS:
        errors.append(f"{label}.rebase_events must contain at most {MAX_REBASE_EVENTS} entries")
        events = []
    last_generation = 0
    for index, event in enumerate(events):
        if not isinstance(event, dict):
            errors.append(f"{label}.rebase_events[{index}] must be an object")
            continue
        generation = event.get("generation")
        if not isinstance(generation, int) or isinstance(generation, bool) or generation <= last_generation:
            errors.append(f"{label}.rebase_events generations must increase strictly")
        else:
            last_generation = generation
        if not _vector(event.get("translation_m")):
            errors.append(f"{label}.rebase_events[{index}].translation_m must be three finite metres")
        if event.get("absolute_position_preserved") is not True:
            errors.append(f"{label}.rebase_events[{index}] must preserve absolute position")
    if events and value.get("origin_generation") != events[-1].get("generation"):
        errors.append(f"{label}.origin_generation must equal the latest rebase generation")
    if not isinstance(value.get("origin_generation"), int) or value.get("origin_generation", 0) < 0:
        errors.append(f"{label}.origin_generation must be a non-negative integer")

    evidence = value.get("evidence")
    if not isinstance(evidence, dict) or not _text(evidence.get("record")):
        errors.append(f"{label}.evidence.record is required")
    authority = value.get("authority")
    if not isinstance(authority, dict):
        errors.append(f"{label}.authority must be an object")
    else:
        for key in ("streaming_runtime", "node_rebase", "terrain_generation", "movement"):
            if authority.get(key) is not False:
                errors.append(f"{label}.authority.{key} must be false")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    args = parser.parse_args(argv)
    errors = validate_manifest(json.loads(args.manifest.read_text(encoding="utf-8")))
    if errors:
        print("PLANETARY_STREAMING_ORIGIN_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PLANETARY_STREAMING_ORIGIN_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
