#!/usr/bin/env python3
"""Validate version-113 source-hash evidence and lineage evidence."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

SCHEMA_VERSION = 113
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


def validate_v113(value: Any, label: str = "evidence_lineage_v113") -> list[str]:
    """Return violations; an empty list means evidence lineage evidence is valid."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    for key in ("build_label", "source_id", "evidence_id", "lineage_id", "source_commit", "source_hash", "source_version", "package_version"):
        if not _text(value.get(key)):
            errors.append(f"{label}.{key} is required")

    evidence = value.get("evidence_record")
    _status(evidence, f"{label}.evidence_record", errors)
    if isinstance(evidence, dict) and evidence.get("status") == "PASS":
        for key in ("evidence_id", "source_id", "source_commit", "source_hash", "source_version", "package_version"):
            if evidence.get(key) != value.get(key):
                errors.append(f"{label}.evidence_record.{key} must match {key}")
        if evidence.get("captured") is not True:
            errors.append(f"{label}.evidence_record.captured must be true when status is PASS")

    lineage = value.get("lineage")
    _status(lineage, f"{label}.lineage", errors)
    if isinstance(lineage, dict) and lineage.get("status") == "PASS":
        for key in ("lineage_id", "evidence_id", "source_id", "source_commit", "source_hash", "source_version", "package_version"):
            if lineage.get(key) != value.get(key):
                errors.append(f"{label}.lineage.{key} must match {key}")
        if lineage.get("traced") is not True:
            errors.append(f"{label}.lineage.traced must be true when status is PASS")

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
    errors = validate_v113(json.loads(args.record.read_text(encoding="utf-8")))
    if errors:
        print("SOURCE_HASH_EVIDENCE_LINEAGE_V113_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("SOURCE_HASH_EVIDENCE_LINEAGE_V113_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
