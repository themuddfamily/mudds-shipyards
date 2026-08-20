#!/usr/bin/env python3
"""Validate source/artifact/package label consistency from recorded metadata."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

STATES = {"PASS", "FAIL", "NOT_RUN", "UNKNOWN"}
SCHEMA_VERSION = 1


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


def validate_labels(value: Any, label: str = "labels") -> list[str]:
    """Return violations; an empty list means labels are consistent."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    candidate = value.get("candidate_label")
    if not _text(candidate):
        errors.append(f"{label}.candidate_label is required")
    source_commit = value.get("source_commit")
    if not _text(source_commit):
        errors.append(f"{label}.source_commit is required")

    source = value.get("source")
    _status(source, f"{label}.source", errors)
    artifact = value.get("artifact")
    _status(artifact, f"{label}.artifact", errors)
    package = value.get("package")
    _status(package, f"{label}.package", errors)
    pck = value.get("pck")
    _status(pck, f"{label}.pck", errors)
    for name, record in (("source", source), ("artifact", artifact), ("package", package), ("pck", pck)):
        if not isinstance(record, dict):
            continue
        if record.get("status") == "PASS":
            if record.get("candidate_label") != candidate:
                errors.append(f"{label}.{name}.candidate_label must match candidate_label")
            if record.get("source_commit") != source_commit:
                errors.append(f"{label}.{name}.source_commit must match source_commit")

    audit = value.get("consistency_audit")
    _status(audit, f"{label}.consistency_audit", errors)
    if isinstance(audit, dict) and audit.get("status") == "PASS" and audit.get("labels_match") is not True:
        errors.append(f"{label}.consistency_audit.labels_match must be true when status is PASS")

    native = value.get("native_execution")
    _status(native, f"{label}.native_execution", errors)
    if isinstance(native, dict) and native.get("status") in {"NOT_RUN", "UNKNOWN"}:
        for key in ("platform", "hardware", "evidence_path"):
            if native.get(key) is not None:
                errors.append(f"{label}.native_execution.{key} must be null when status is {native['status']}")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("record", type=Path)
    args = parser.parse_args(argv)
    errors = validate_labels(json.loads(args.record.read_text(encoding="utf-8")))
    if errors:
        print("SOURCE_ARTIFACT_LABELS_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("SOURCE_ARTIFACT_LABELS_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
