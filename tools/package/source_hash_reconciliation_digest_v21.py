#!/usr/bin/env python3
"""Validate version-21 source/hash reconciliation digest evidence."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

SCHEMA_VERSION = 21
STATES = {"PASS", "FAIL", "NOT_RUN", "UNKNOWN"}
HEX64 = re.compile(r"^[0-9a-fA-F]{64}$")


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _digest(value: Any) -> bool:
    return _text(value) and bool(HEX64.fullmatch(value.strip()))


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


def validate_v21(value: Any, label: str = "reconciliation_v21") -> list[str]:
    """Return violations; an empty list means reconciliation digest evidence is valid."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    for key in ("build_label", "source_commit", "reconciliation_id", "reconciliation_digest"):
        if not _text(value.get(key)):
            errors.append(f"{label}.{key} is required")
    if _text(value.get("reconciliation_digest")) and not _digest(value["reconciliation_digest"]):
        errors.append(f"{label}.reconciliation_digest must be a 64-character hex digest")
    source = value.get("source")
    _status(source, f"{label}.source", errors)
    if isinstance(source, dict) and source.get("status") == "PASS":
        if source.get("source_commit") != value.get("source_commit"):
            errors.append(f"{label}.source.source_commit must match source_commit")
        if not _text(source.get("manifest_digest")):
            errors.append(f"{label}.source.manifest_digest is required when status is PASS")
    digest = value.get("digest")
    _status(digest, f"{label}.digest", errors)
    if isinstance(digest, dict) and digest.get("status") == "PASS":
        if digest.get("value") != value.get("reconciliation_digest"):
            errors.append(f"{label}.digest.value must match reconciliation_digest")
        if digest.get("reconciliation_id") != value.get("reconciliation_id"):
            errors.append(f"{label}.digest.reconciliation_id must match reconciliation_id")
    reconciliation = value.get("reconciliation")
    _status(reconciliation, f"{label}.reconciliation", errors)
    if isinstance(reconciliation, dict) and reconciliation.get("status") == "PASS":
        if reconciliation.get("reconciliation_id") != value.get("reconciliation_id"):
            errors.append(f"{label}.reconciliation.reconciliation_id must match reconciliation_id")
        if reconciliation.get("digest") != value.get("reconciliation_digest"):
            errors.append(f"{label}.reconciliation.digest must match reconciliation_digest")
        if reconciliation.get("source_commit") != value.get("source_commit"):
            errors.append(f"{label}.reconciliation.source_commit must match source_commit")
        if reconciliation.get("consistent") is not True:
            errors.append(f"{label}.reconciliation.consistent must be true when status is PASS")
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
    errors = validate_v21(json.loads(args.record.read_text(encoding="utf-8")))
    if errors:
        print("SOURCE_HASH_RECONCILIATION_DIGEST_V21_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("SOURCE_HASH_RECONCILIATION_DIGEST_V21_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
