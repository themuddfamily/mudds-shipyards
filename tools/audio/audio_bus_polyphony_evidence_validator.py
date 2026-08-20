#!/usr/bin/env python3
"""Validate per-bus audio/polyphony budget evidence without native mixer claims."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


SCHEMA = "audio_bus_polyphony_evidence_v1"
REQUIRED_BUSES = {"Music", "SFX", "Ambience", "UI"}
BACKENDS = {"scene_graph", "dummy_audio"}


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _integer(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value >= 0


def validate_report(report: Any) -> list[str]:
    if not isinstance(report, dict):
        return ["report must be an object"]
    errors: list[str] = []
    if report.get("schema") != SCHEMA:
        errors.append(f"schema must be {SCHEMA}")
    source = report.get("source")
    if not isinstance(source, dict):
        errors.append("source must be an object")
        source = {}
    for key in ("revision", "evidence_path"):
        if not _text(source.get(key)):
            errors.append(f"source.{key} is required")
    backend = report.get("measurement_backend")
    if backend not in BACKENDS:
        errors.append("measurement_backend must be scene_graph or dummy_audio")
    if report.get("native_mixer_status") != "OPEN":
        errors.append("native_mixer_status must be OPEN until native measurement exists")

    buses = report.get("buses")
    if not isinstance(buses, list) or not buses:
        errors.append("buses must be a non-empty array")
        buses = []
    names: set[str] = set()
    for index, bus in enumerate(buses):
        prefix = f"buses[{index}]"
        if not isinstance(bus, dict):
            errors.append(f"{prefix} must be an object")
            continue
        name = bus.get("name")
        if name not in REQUIRED_BUSES:
            errors.append(f"{prefix}.name is invalid")
        elif name in names:
            errors.append(f"{prefix}.name is duplicated")
        else:
            names.add(name)
        for key in ("declared_polyphony", "observed_peak_polyphony"):
            if not _integer(bus.get(key)):
                errors.append(f"{prefix}.{key} must be a non-negative integer")
        if _integer(bus.get("declared_polyphony")) and _integer(bus.get("observed_peak_polyphony")) and bus["observed_peak_polyphony"] > bus["declared_polyphony"]:
            errors.append(f"{prefix}.observed_peak_polyphony exceeds declared_polyphony")
        if not _text(bus.get("evidence")):
            errors.append(f"{prefix}.evidence is required")
        if bus.get("native_observed") is not False:
            errors.append(f"{prefix}.native_observed must be false for this non-native report")
    missing = REQUIRED_BUSES - names
    if missing:
        errors.append(f"buses must cover: {', '.join(sorted(missing))}")

    if report.get("claim") == "AUTOMATED_BUDGET_ONLY":
        if not _text(report.get("boundary_note")):
            errors.append("boundary_note is required for AUTOMATED_BUDGET_ONLY")
    elif report.get("claim") == "NATIVE_MIXER_OBSERVED":
        errors.append("NATIVE_MIXER_OBSERVED is not allowed by this non-native report")
    else:
        errors.append("claim must be AUTOMATED_BUDGET_ONLY")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("report", type=Path)
    args = parser.parse_args(argv)
    errors = validate_report(json.loads(args.report.read_text(encoding="utf-8")))
    if errors:
        print("AUDIO_BUS_POLYPHONY_EVIDENCE_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("AUDIO_BUS_POLYPHONY_EVIDENCE_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
