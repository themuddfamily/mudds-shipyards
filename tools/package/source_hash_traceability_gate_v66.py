#!/usr/bin/env python3
"""Validate version-66 source-hash traceability and release-gate evidence."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

SCHEMA_VERSION = 66
STATES = {"PASS", "FAIL", "NOT_RUN", "UNKNOWN"}


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _status(record: Any, label: str, errors: list[str]) -> None:
    if not isinstance(record, dict):
        errors.append(f"{label} must be an object")
        return
    status = record.get("status")
    if status not in STATES:
        errors.append(f"{label}.status is invalid")
        return
    if status == "PASS" and not _text(record.get("evidence")):
        errors.append(f"{label}.evidence is required when status is PASS")
    if status in {"NOT_RUN", "UNKNOWN"} and record.get("evidence") is not None:
        errors.append(f"{label}.evidence must be null when status is {status}")


def validate_v66(value: Any, label: str = "traceability_gate_v66") -> list[str]:
    """Return violations; an empty list means traceability gate evidence is valid."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    for key in ("build_label", "source_id", "trace_id", "gate_id", "source_commit", "source_hash", "source_version", "package_version"):
        if not _text(value.get(key)):
            errors.append(f"{label}.{key} is required")

    traceability = value.get("traceability")
    _status(traceability, f"{label}.traceability", errors)
    if isinstance(traceability, dict) and traceability.get("status") == "PASS":
        for key in ("trace_id", "source_id", "source_commit", "source_hash", "source_version", "package_version"):
            if traceability.get(key) != value.get(key):
                errors.append(f"{label}.traceability.{key} must match {key}")
        if traceability.get("traceable") is not True:
            errors.append(f"{label}.traceability.traceable must be true when status is PASS")

    gate = value.get("gate")
    _status(gate, f"{label}.gate", errors)
    if isinstance(gate, dict) and gate.get("status") == "PASS":
        for key in ("gate_id", "trace_id", "source_id", "source_commit", "source_hash", "source_version", "package_version"):
            if gate.get(key) != value.get(key):
                errors.append(f"{label}.gate.{key} must match {key}")
        if gate.get("passed") is not True:
            errors.append(f"{label}.gate.passed must be true when status is PASS")

    native = value.get("native_execution")
    _status(native, f"{label}.native_execution", errors)
    if isinstance(native, dict) and native.get("status") == "NOT_RUN":
        for key in ("platform", "hardware", "evidence_path"):
            if native.get(key) is not None:
                errors.append(f"{label}.native_execution.{key} must be null when status is NOT_RUN")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("record", type=Path)
    args = parser.parse_args(argv)
    errors = validate_v66(json.loads(args.record.read_text(encoding="utf-8")))
    if errors:
        print("SOURCE_HASH_TRACEABILITY_GATE_V66_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("SOURCE_HASH_TRACEABILITY_GATE_V66_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
