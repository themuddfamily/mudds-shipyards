#!/usr/bin/env python3
"""Validate an audio mix, voice-ceiling, and human-listening audit record.

This is a claim-safety gate.  A Dummy/headless run may establish the declared
voice ceiling, but it cannot establish bus balance or audibility.  Native
output evidence and a real listening pass therefore remain explicit fields in
the record rather than being inferred from a successful test run.
"""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 1
BACKENDS = {"native_output", "dummy", "unknown"}
BALANCE_STATUSES = {"NATIVE_CAPTURED", "DUMMY_ONLY", "NOT_RUN"}
LISTENING_STATUSES = {"PASS", "FAIL", "OUTSTANDING", "NOT_RUN"}


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _finite_number(value: Any) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(float(value))


def _non_negative_integer(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value >= 0


def _unique_strings(value: Any) -> bool:
    return isinstance(value, list) and all(_text(item) for item in value) and len(value) == len(set(value))


def validate_manifest(manifest: Any, label: str = "manifest") -> list[str]:
    """Return blocking structural/claim-safety errors for one audit record."""
    if not isinstance(manifest, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if manifest.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    for key in ("build_label", "source_commit"):
        if not _text(manifest.get(key)):
            errors.append(f"{label}.{key} is required")

    measurement = manifest.get("measurement")
    if not isinstance(measurement, dict):
        errors.append(f"{label}.measurement must be an object")
        measurement = {}
    backend = measurement.get("backend")
    if backend not in BACKENDS:
        errors.append(f"{label}.measurement.backend is invalid")
    if backend == "native_output" and not _text(measurement.get("device")):
        errors.append(f"{label}.measurement.device is required for native output")
    if not _non_negative_integer(measurement.get("sample_rate_hz")) or measurement.get("sample_rate_hz") == 0:
        errors.append(f"{label}.measurement.sample_rate_hz must be a positive integer")
    if not _finite_number(measurement.get("duration_seconds")) or float(measurement.get("duration_seconds")) <= 0:
        errors.append(f"{label}.measurement.duration_seconds must be positive")

    balance = manifest.get("bus_balance")
    if not isinstance(balance, dict):
        errors.append(f"{label}.bus_balance must be an object")
        balance = {}
    balance_status = balance.get("status")
    if balance_status not in BALANCE_STATUSES:
        errors.append(f"{label}.bus_balance.status is invalid")
    if balance_status == "NATIVE_CAPTURED" and backend != "native_output":
        errors.append(f"{label}.bus_balance.NATIVE_CAPTURED requires native_output measurement")
    if balance_status == "NATIVE_CAPTURED" and not _text(balance.get("evidence")):
        errors.append(f"{label}.bus_balance.evidence is required for native capture")
    rows = balance.get("buses")
    if not isinstance(rows, list) or not rows:
        errors.append(f"{label}.bus_balance.buses must be a non-empty array")
        rows = []
    names: list[str] = []
    for index, row in enumerate(rows):
        prefix = f"{label}.bus_balance.buses[{index}]"
        if not isinstance(row, dict):
            errors.append(f"{prefix} must be an object")
            continue
        name = row.get("name")
        if not _text(name):
            errors.append(f"{prefix}.name is required")
        elif name in names:
            errors.append(f"{prefix}.name is duplicated")
        else:
            names.append(name)
        for key in ("observed_peak_dbfs", "target_peak_dbfs", "tolerance_db"):
            if not _finite_number(row.get(key)):
                errors.append(f"{prefix}.{key} must be finite")
        if all(_finite_number(row.get(key)) for key in ("observed_peak_dbfs", "target_peak_dbfs", "tolerance_db")):
            if float(row["tolerance_db"]) < 0:
                errors.append(f"{prefix}.tolerance_db must be non-negative")
            elif abs(float(row["observed_peak_dbfs"]) - float(row["target_peak_dbfs"])) > float(row["tolerance_db"]):
                errors.append(f"{prefix}.observed_peak_dbfs is outside its target tolerance")
    if balance_status == "DUMMY_ONLY" and backend == "native_output":
        errors.append(f"{label}.bus_balance.DUMMY_ONLY conflicts with native_output measurement")

    voices = manifest.get("voice_ceiling")
    if not isinstance(voices, dict):
        errors.append(f"{label}.voice_ceiling must be an object")
        voices = {}
    for key in ("declared", "observed_peak"):
        if not _non_negative_integer(voices.get(key)):
            errors.append(f"{label}.voice_ceiling.{key} must be a non-negative integer")
    if _non_negative_integer(voices.get("declared")) and _non_negative_integer(voices.get("observed_peak")):
        if voices["observed_peak"] > voices["declared"]:
            errors.append(f"{label}.voice_ceiling.observed_peak exceeds declared ceiling")
    if not _text(voices.get("evidence")):
        errors.append(f"{label}.voice_ceiling.evidence is required")

    listening = manifest.get("human_listening")
    if not isinstance(listening, dict):
        errors.append(f"{label}.human_listening must be an object")
        listening = {}
    listening_status = listening.get("status")
    if listening_status not in LISTENING_STATUSES:
        errors.append(f"{label}.human_listening.status is invalid")
    if listening_status == "PASS":
        for key in ("reviewer", "device", "notes"):
            if not _text(listening.get(key)):
                errors.append(f"{label}.human_listening.{key} is required for PASS")
        for key in ("mix_levels", "distances"):
            if not _unique_strings(listening.get(key)) or not listening.get(key):
                errors.append(f"{label}.human_listening.{key} must be a non-empty unique array")
        if backend != "native_output":
            errors.append(f"{label}.human_listening.PASS requires native_output measurement")
    elif listening_status in {"OUTSTANDING", "NOT_RUN"} and not _text(listening.get("notes")):
        errors.append(f"{label}.human_listening.notes is required while listening is incomplete")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    args = parser.parse_args(argv)
    errors = validate_manifest(json.loads(args.manifest.read_text(encoding="utf-8")))
    if errors:
        print("AUDIO_MIX_LISTENING_AUDIT_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("AUDIO_MIX_LISTENING_AUDIT_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
