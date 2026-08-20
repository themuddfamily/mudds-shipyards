#!/usr/bin/env python3
"""Validate version-26 source/hash digest reconciliation evidence."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

SCHEMA_VERSION = 26
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


def validate_v26(value: Any, label: str = "digest_v26") -> list[str]:
    """Return violations; an empty list means digest reconciliation is valid."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    for key in ("build_label", "source_commit", "digest_id", "digest_value", "reconciliation_id"):
        if not _text(value.get(key)):
            errors.append(f"{label}.{key} is required")
    if _text(value.get("digest_value")) and not _digest(value["digest_value"]):
        errors.append(f"{label}.digest_value must be a 64-character hex digest")
    digest = value.get("digest")
    _status(digest, f"{label}.digest", errors)
    if isinstance(digest, dict) and digest.get("status") == "PASS":
        if digest.get("digest_id") != value.get("digest_id"):
            errors.append(f"{label}.digest.digest_id must match digest_id")
        if digest.get("value") != value.get("digest_value"):
            errors.append(f"{label}.digest.value must match digest_value")
        if digest.get("source_commit") != value.get("source_commit"):
            errors.append(f"{label}.digest.source_commit must match source_commit")
    reconciliation = value.get("reconciliation")
    _status(reconciliation, f"{label}.reconciliation", errors)
    if isinstance(reconciliation, dict) and reconciliation.get("status") == "PASS":
        for key in ("digest_id", "reconciliation_id"):
            if reconciliation.get(key) != value.get(key):
                errors.append(f"{label}.reconciliation.{key} must match {key}")
        if reconciliation.get("value") != value.get("digest_value"):
            errors.append(f"{label}.reconciliation.value must match digest_value")
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
    errors = validate_v26(json.loads(args.record.read_text(encoding="utf-8")))
    if errors:
        print("SOURCE_HASH_DIGEST_RECONCILIATION_V26_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("SOURCE_HASH_DIGEST_RECONCILIATION_V26_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
