#!/usr/bin/env python3
"""Validate native performance/audio observation metadata without running it."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


SCHEMA = "native_performance_audio_observation_v1"
REQUIRED_SCENARIOS = {"station_route", "combat_route", "return_reentry"}
REQUIRED_METRICS = {"frame_time_ms", "gpu_frame_time_ms", "audio_native_voices", "audio_output_latency_ms"}


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _number(value: Any) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool) and value >= 0


def validate_record(record: Any) -> list[str]:
    if not isinstance(record, dict):
        return ["record must be an object"]
    errors: list[str] = []
    if record.get("schema") != SCHEMA:
        errors.append(f"schema must be {SCHEMA}")
    source = record.get("source")
    if not isinstance(source, dict):
        errors.append("source must be an object")
        source = {}
    if not _text(source.get("revision")):
        errors.append("source.revision is required")
    if source.get("dirty") is not False:
        errors.append("source.dirty must be false")

    target = record.get("target_hardware")
    if not isinstance(target, dict):
        errors.append("target_hardware must be an object")
        target = {}
    for key in ("platform", "cpu", "gpu", "audio_device"):
        if not _text(target.get(key)):
            errors.append(f"target_hardware.{key} is required")
    if target.get("status") not in {"OPEN", "OBSERVED", "FAILED"}:
        errors.append("target_hardware.status is invalid")

    scenarios = record.get("scenarios")
    if not isinstance(scenarios, list) or any(not isinstance(row, dict) for row in scenarios):
        errors.append("scenarios must be an array of objects")
        scenarios = []
    names = {row.get("name") for row in scenarios}
    if len(names) != len(scenarios):
        errors.append("scenarios.name must be unique")
    if not REQUIRED_SCENARIOS.issubset(names):
        errors.append("scenarios must cover station_route, combat_route, and return_reentry")
    for index, scenario in enumerate(scenarios):
        prefix = f"scenarios[{index}]"
        if not _text(scenario.get("name")):
            errors.append(f"{prefix}.name is required")
        if not _text(scenario.get("evidence")):
            errors.append(f"{prefix}.evidence is required")
        observations = scenario.get("observations")
        if not isinstance(observations, dict):
            errors.append(f"{prefix}.observations must be an object")
            continue
        missing = REQUIRED_METRICS - set(observations)
        if missing:
            errors.append(f"{prefix}.observations missing {', '.join(sorted(missing))}")
        for metric, value in observations.items():
            metric_prefix = f"{prefix}.observations.{metric}"
            if metric not in REQUIRED_METRICS:
                errors.append(f"{metric_prefix} is not a supported metric")
                continue
            if not isinstance(value, dict):
                errors.append(f"{metric_prefix} must be an object")
                continue
            if not isinstance(value.get("available"), bool):
                errors.append(f"{metric_prefix}.available must be boolean")
            if value.get("available") is True and not _number(value.get("value")):
                errors.append(f"{metric_prefix}.value must be non-negative when available")
            if value.get("available") is not True and value.get("value") is not None:
                errors.append(f"{metric_prefix}.value must be null when unavailable")
            if not _text(value.get("source")):
                errors.append(f"{metric_prefix}.source is required")

    if record.get("claim") == "SCHEMA_ONLY":
        if target.get("status") != "OPEN":
            errors.append("SCHEMA_ONLY requires target_hardware.status OPEN")
        if not _text(record.get("boundary_note")):
            errors.append("boundary_note is required for SCHEMA_ONLY")
    elif record.get("claim") == "NATIVE_OBSERVED":
        if target.get("status") != "OBSERVED":
            errors.append("NATIVE_OBSERVED requires target_hardware.status OBSERVED")
    else:
        errors.append("claim must be SCHEMA_ONLY or NATIVE_OBSERVED")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("record", type=Path)
    args = parser.parse_args(argv)
    errors = validate_record(json.loads(args.record.read_text(encoding="utf-8")))
    if errors:
        print("NATIVE_PERFORMANCE_AUDIO_OBSERVATION_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("NATIVE_PERFORMANCE_AUDIO_OBSERVATION_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
