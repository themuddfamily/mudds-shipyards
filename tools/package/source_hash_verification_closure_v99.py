#!/usr/bin/env python3
"""Validate version-99 source-hash verification and closure evidence."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

SCHEMA_VERSION = 99
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


def validate_v99(value: Any, label: str = "verification_closure_v99") -> list[str]:
    """Return violations; an empty list means verification closure evidence is valid."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    for key in ("build_label", "source_id", "verification_id", "closure_id", "source_commit", "source_hash", "source_version", "package_version"):
        if not _text(value.get(key)):
            errors.append(f"{label}.{key} is required")

    verification = value.get("verification")
    _status(verification, f"{label}.verification", errors)
    if isinstance(verification, dict) and verification.get("status") == "PASS":
        for key in ("verification_id", "source_id", "source_commit", "source_hash", "source_version", "package_version"):
            if verification.get(key) != value.get(key):
                errors.append(f"{label}.verification.{key} must match {key}")
        if verification.get("verified") is not True:
            errors.append(f"{label}.verification.verified must be true when status is PASS")

    closure = value.get("closure")
    _status(closure, f"{label}.closure", errors)
    if isinstance(closure, dict) and closure.get("status") == "PASS":
        for key in ("closure_id", "verification_id", "source_id", "source_commit", "source_hash", "source_version", "package_version"):
            if closure.get(key) != value.get(key):
                errors.append(f"{label}.closure.{key} must match {key}")
        if closure.get("closed") is not True:
            errors.append(f"{label}.closure.closed must be true when status is PASS")

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
    errors = validate_v99(json.loads(args.record.read_text(encoding="utf-8")))
    if errors:
        print("SOURCE_HASH_VERIFICATION_CLOSURE_V99_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("SOURCE_HASH_VERIFICATION_CLOSURE_V99_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
