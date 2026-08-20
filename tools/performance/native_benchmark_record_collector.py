#!/usr/bin/env python3
"""Normalize metrics supplied by an external native benchmark harness.

This module intentionally does not launch Godot, inspect a GPU, or infer a
measurement from a missing field.  A native Windows harness can hand it a JSON
object (usually ``{"source": ..., "metrics": {...}}``); the result has the
``native_metrics`` shape consumed by :mod:`benchmark_record_validator`.
Malformed, missing, unavailable, or unit-mismatched values are represented as
unavailable values.  That fail-closed behaviour prevents a partial external
dump from being mistaken for native performance evidence.
"""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
from typing import Any


METRIC_FIELDS = {
    "frame_time_ms": "milliseconds",
    "gpu_frame_time_ms": "milliseconds",
    "ram_bytes": "bytes",
    "vram_bytes": "bytes",
    "draw_calls": "count",
}


def _valid_number(value: Any) -> bool:
    return (
        isinstance(value, (int, float))
        and not isinstance(value, bool)
        and math.isfinite(float(value))
        and value >= 0
    )


def _unavailable(unit: str, source: str) -> dict[str, Any]:
    return {"available": False, "value": None, "unit": unit, "source": source}


def collect_native_metrics(payload: Any) -> dict[str, dict[str, Any]]:
    """Return validator-compatible native metrics from an external JSON dump.

    ``payload`` may contain a ``metrics`` or ``native_metrics`` object.  Each
    metric may be a scalar, or an object containing ``value``, ``unit``,
    ``available`` and ``source``.  Every known metric is emitted, including
    unavailable ones.  A non-object payload is rejected because silently
    treating an invalid file as an empty measurement is too easy to miss.
    """

    if not isinstance(payload, dict):
        raise ValueError("external benchmark payload must be an object")
    raw = payload.get("metrics", payload.get("native_metrics", {}))
    if not isinstance(raw, dict):
        raise ValueError("external benchmark metrics must be an object")
    payload_source = payload.get("source", "external native collector")
    if not isinstance(payload_source, str) or not payload_source.strip():
        payload_source = "external native collector"

    result: dict[str, dict[str, Any]] = {}
    for name, unit in METRIC_FIELDS.items():
        entry = raw.get(name)
        if isinstance(entry, dict):
            source = entry.get("source", payload_source)
            if not isinstance(source, str) or not source.strip():
                source = "invalid external provenance"
            if entry.get("available") is False:
                result[name] = _unavailable(unit, source)
                continue
            value = entry.get("value")
            supplied_unit = entry.get("unit", unit)
        else:
            source = payload_source
            value = entry
            supplied_unit = unit

        if supplied_unit != unit:
            result[name] = _unavailable(unit, f"unit mismatch in external dump: {supplied_unit!r}")
        elif not _valid_number(value):
            result[name] = _unavailable(unit, f"unavailable or invalid external value for {name}")
        elif not isinstance(source, str) or not source.strip():
            result[name] = _unavailable(unit, "missing external provenance")
        else:
            result[name] = {
                "available": True,
                "value": value,
                "unit": unit,
                "source": source.strip(),
            }
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path, help="external native metrics JSON")
    parser.add_argument("--output", type=Path, help="write normalized native_metrics JSON")
    args = parser.parse_args()
    try:
        normalized = collect_native_metrics(json.loads(args.input.read_text(encoding="utf-8")))
    except (OSError, json.JSONDecodeError, ValueError) as exc:
        print(f"NATIVE_BENCHMARK_INPUT_INVALID: {exc}")
        return 1
    text = json.dumps(normalized, indent=2, sort_keys=True) + "\n"
    if args.output:
        args.output.write_text(text, encoding="utf-8")
    else:
        print(text, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
