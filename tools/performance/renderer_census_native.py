#!/usr/bin/env python3
"""Normalize renderer counters captured by a native hardware harness.

The Godot scene census deliberately cannot measure driver draw submissions,
GPU time, or VRAM.  A Windows harness may provide those values here after a
real display/GPU run.  This adapter only normalizes and validates that dump;
it never probes the host and never upgrades a software-renderer capture into
native evidence.
"""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 1
REPORT_KIND = "native_renderer_census"
FIELDS = {
    "draw_calls": "count",
    "gpu_frame_time_ms": "milliseconds",
    "vram_bytes": "bytes",
}
SOFTWARE_TOKENS = (
    "llvmpipe",
    "softpipe",
    "lavapipe",
    "swiftshader",
    "software rasterizer",
    "software renderer",
)


def _finite_nonnegative(value: Any) -> bool:
    return (
        isinstance(value, (int, float))
        and not isinstance(value, bool)
        and math.isfinite(float(value))
        and float(value) >= 0
    )


def _percentile(values: list[float], fraction: float) -> float:
    ordered = sorted(values)
    if len(ordered) == 1:
        return ordered[0]
    position = fraction * (len(ordered) - 1)
    lower = int(position)
    upper = min(lower + 1, len(ordered) - 1)
    return ordered[lower] + (ordered[upper] - ordered[lower]) * (position - lower)


def _software_claim(payload: dict[str, Any]) -> str | None:
    if payload.get("software_renderer") is True:
        return "software_renderer=true"
    # Keep this deliberately shallow and deterministic: these are identity
    # fields, not arbitrary benchmark sample text.
    identity = []
    for key in ("renderer", "adapter", "gpu", "device", "driver", "renderer_name"):
        value = payload.get(key)
        if isinstance(value, str):
            identity.append(value)
    identity_text = " ".join(identity).lower()
    for token in SOFTWARE_TOKENS:
        if token in identity_text:
            return f"software renderer identity contains {token!r}"
    return None


def _unavailable(unit: str, source: str) -> dict[str, Any]:
    return {
        "available": False,
        "unit": unit,
        "samples": [],
        "summary": None,
        "source": source,
    }


def _normalize_field(raw: Any, unit: str, source: str, name: str) -> dict[str, Any]:
    supplied_unit = unit
    field_source = source
    if isinstance(raw, dict):
        supplied_unit = raw.get("unit", unit)
        field_source = raw.get("source", source)
        if not isinstance(field_source, str) or not field_source.strip():
            field_source = "invalid native provenance"
        if raw.get("available") is False:
            return _unavailable(unit, field_source)
        raw = raw.get("samples", raw.get("values", raw.get("value")))
    if supplied_unit != unit:
        return _unavailable(unit, f"unit mismatch for {name}: {supplied_unit!r}")
    values = raw if isinstance(raw, list) else [raw]
    if not values or not all(_finite_nonnegative(value) for value in values):
        return _unavailable(unit, f"invalid native value for {name}")
    if not isinstance(field_source, str) or not field_source.strip():
        return _unavailable(unit, "missing native provenance")
    samples = [float(value) for value in values]
    # Preserve integral counters as integers for machine-readable evidence.
    if unit in ("count", "bytes"):
        samples = [int(value) if value.is_integer() else value for value in samples]
    summary = {
        "count": len(samples),
        "min": min(samples),
        "p50": _percentile([float(value) for value in samples], 0.50),
        "p95": _percentile([float(value) for value in samples], 0.95),
        "p99": _percentile([float(value) for value in samples], 0.99),
        "max": max(samples),
    }
    return {
        "available": True,
        "unit": unit,
        "samples": samples,
        "summary": summary,
        "source": field_source.strip(),
    }


def normalize_renderer_census(payload: Any) -> dict[str, Any]:
    """Return a strict native renderer census from an external JSON object.

    Missing metrics remain explicitly unavailable.  A software-renderer
    identity is rejected rather than emitted as native evidence.
    """
    if not isinstance(payload, dict):
        raise ValueError("native renderer census payload must be an object")
    software_reason = _software_claim(payload)
    if software_reason:
        raise ValueError(f"software renderer is not native evidence: {software_reason}")
    source = payload.get("source", "external native renderer census")
    if not isinstance(source, str) or not source.strip():
        source = "external native renderer census"
    raw = payload.get("metrics", payload.get("renderer_metrics", {}))
    if not isinstance(raw, dict):
        raise ValueError("native renderer metrics must be an object")
    metrics = {
        name: _normalize_field(raw.get(name), unit, source, name)
        for name, unit in FIELDS.items()
    }
    return {
        "schema_version": SCHEMA_VERSION,
        "report_kind": REPORT_KIND,
        "source": source.strip(),
        "platform": payload.get("platform", "unknown"),
        "renderer": payload.get("renderer", "unknown"),
        "software_renderer": False,
        "metrics": metrics,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    try:
        normalized = normalize_renderer_census(
            json.loads(args.input.read_text(encoding="utf-8"))
        )
    except (OSError, json.JSONDecodeError, ValueError) as exc:
        print(f"NATIVE_RENDERER_CENSUS_INVALID: {exc}")
        return 1
    text = json.dumps(normalized, indent=2, sort_keys=True) + "\n"
    if args.output:
        args.output.write_text(text, encoding="utf-8")
    else:
        print(text, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
