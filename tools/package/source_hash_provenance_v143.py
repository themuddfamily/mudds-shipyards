#!/usr/bin/env python3
"""Validate version-143 package source-hash provenance evidence."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

SCHEMA_VERSION = 143
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


def validate_v143(value: Any, label: str = "source_provenance_v143") -> list[str]:
    """Return violations; an empty list means v143 evidence is valid."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    fields = ("build_label", "source_id", "provenance_id", "source_commit", "source_hash", "source_version", "package_version", "source_author", "package_publisher")
    for key in fields:
        if not _text(value.get(key)):
            errors.append(f"{label}.{key} is required")
    binding_fields = ("source_id", "source_commit", "source_hash", "source_version", "package_version", "source_author", "package_publisher")

    source = value.get("source")
    _status(source, f"{label}.source", errors)
    if isinstance(source, dict) and source.get("status") == "PASS":
        for key in binding_fields:
            if source.get(key) != value.get(key):
                errors.append(f"{label}.source.{key} must match {key}")
        if source.get("identified") is not True:
            errors.append(f"{label}.source.identified must be true when status is PASS")

    provenance = value.get("provenance")
    _status(provenance, f"{label}.provenance", errors)
    if isinstance(provenance, dict) and provenance.get("status") == "PASS":
        for key in ("provenance_id",) + binding_fields:
            if provenance.get(key) != value.get(key):
                errors.append(f"{label}.provenance.{key} must match {key}")
        if provenance.get("proven") is not True:
            errors.append(f"{label}.provenance.proven must be true when status is PASS")

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
    errors = validate_v143(json.loads(args.record.read_text(encoding="utf-8")))
    if errors:
        print("SOURCE_HASH_PROVENANCE_V143_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("SOURCE_HASH_PROVENANCE_V143_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
