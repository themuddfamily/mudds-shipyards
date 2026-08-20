#!/usr/bin/env python3
"""Fail-closed validator for planetary tile residency and memory evidence.

This gate validates measured tile counts and byte totals; it does not invent
values for absent telemetry or turn a headless run into native GPU evidence.
Native provenance is retained in the report so callers can distinguish the
stronger package/native gate from a renderer-independent structural census.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

SCHEMA_VERSION = 1
_SHA256 = re.compile(r"^[0-9a-f]{64}$")
_EXECUTION_MODES = {"native_windows", "headless_linux", "headless_windows"}
_METRICS = ("resident_tiles", "loaded_tiles", "resident_bytes", "loaded_bytes")


def _non_negative_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value >= 0


def validate_report(report: Any, label: str = "report") -> list[str]:
    if not isinstance(report, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if report.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    if not isinstance(report.get("scenario"), str) or not report["scenario"]:
        errors.append(f"{label}.scenario must be a non-empty string")
    if not _non_negative_int(report.get("sample_frames")) or report.get("sample_frames") < 1:
        errors.append(f"{label}.sample_frames must be a positive integer")
    if report.get("measurement_scope") != "planetary_streamed_tiles_and_process_resident_memory":
        errors.append(f"{label}.measurement_scope is not the LOD/streaming census scope")

    tiles = report.get("tiles")
    if not isinstance(tiles, dict):
        errors.append(f"{label}.tiles must be an object")
    else:
        for key in ("resident_count", "loaded_count"):
            if not _non_negative_int(tiles.get(key)):
                errors.append(f"{label}.tiles.{key} must be a non-negative integer")
        if (_non_negative_int(tiles.get("resident_count")) and
                _non_negative_int(tiles.get("loaded_count")) and
                tiles["resident_count"] > tiles["loaded_count"]):
            errors.append(f"{label}.tiles.resident_count cannot exceed loaded_count")

    memory = report.get("memory")
    if not isinstance(memory, dict):
        errors.append(f"{label}.memory must be an object")
    else:
        for key in ("resident_bytes", "loaded_bytes"):
            if not _non_negative_int(memory.get(key)):
                errors.append(f"{label}.memory.{key} must be a non-negative integer")
        if (_non_negative_int(memory.get("resident_bytes")) and
                _non_negative_int(memory.get("loaded_bytes")) and
                memory["resident_bytes"] > memory["loaded_bytes"]):
            errors.append(f"{label}.memory.resident_bytes cannot exceed loaded_bytes")
        if memory.get("unknown_bytes") not in (0, None):
            errors.append(f"{label}.memory.unknown_bytes must be zero; unknown bytes cannot pass a ceiling")

    provenance = report.get("native_provenance")
    if not isinstance(provenance, dict):
        errors.append(f"{label}.native_provenance must be an object")
    else:
        if provenance.get("execution_mode") not in _EXECUTION_MODES:
            errors.append(f"{label}.native_provenance.execution_mode is invalid")
        if not isinstance(provenance.get("platform"), str) or not provenance["platform"]:
            errors.append(f"{label}.native_provenance.platform must be a non-empty string")
        digest = provenance.get("executable_sha256")
        if not isinstance(digest, str) or not _SHA256.fullmatch(digest):
            errors.append(f"{label}.native_provenance.executable_sha256 must be a lowercase SHA-256")
        if not isinstance(provenance.get("capture_id"), str) or not provenance["capture_id"]:
            errors.append(f"{label}.native_provenance.capture_id must be a non-empty string")

    if report.get("fabricated_metrics") is not False:
        errors.append(f"{label}.fabricated_metrics must be false")
    statuses = report.get("metric_status")
    if not isinstance(statuses, dict):
        errors.append(f"{label}.metric_status must be an object")
    else:
        for metric in _METRICS:
            if statuses.get(metric) != "measured":
                errors.append(f"{label}.metric_status.{metric} must be measured")
    exclusions = report.get("authority_exclusions")
    if not isinstance(exclusions, list) or len(exclusions) != len(set(exclusions)):
        errors.append(f"{label}.authority_exclusions must be a unique array")
    else:
        for required in ("gpu_memory", "native_frame_time", "terrain_generation", "fabricated_metrics"):
            if required not in exclusions:
                errors.append(f"{label}.authority_exclusions missing {required}")
    return errors


def validate_budget(report: Any, target: Any) -> list[str]:
    errors = validate_report(report)
    budgets = target.get("lod_streaming_budgets", target) if isinstance(target, dict) else None
    if not isinstance(budgets, dict):
        return errors + ["LOD/streaming budgets must be an object"]
    tiles = report.get("tiles", {}) if isinstance(report, dict) else {}
    memory = report.get("memory", {}) if isinstance(report, dict) else {}
    actual = {
        "resident_tiles": tiles.get("resident_count"), "loaded_tiles": tiles.get("loaded_count"),
        "resident_bytes": memory.get("resident_bytes"), "loaded_bytes": memory.get("loaded_bytes"),
    }
    for metric in _METRICS:
        ceiling = budgets.get(f"max_{metric}")
        if not _non_negative_int(ceiling):
            errors.append(f"LOD/streaming budget max_{metric} must be a non-negative integer")
        elif _non_negative_int(actual[metric]) and actual[metric] > ceiling:
            errors.append(f"LOD/streaming {metric} exceeds budget ({actual[metric]} > {ceiling})")
    return errors


validate_census = validate_budget


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("report", type=Path)
    parser.add_argument("--budgets", required=True, type=Path)
    args = parser.parse_args()
    errors = validate_budget(json.loads(args.report.read_text()), json.loads(args.budgets.read_text()))
    if errors:
        print("LOD_STREAMING_BUDGET_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("LOD_STREAMING_BUDGET_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
