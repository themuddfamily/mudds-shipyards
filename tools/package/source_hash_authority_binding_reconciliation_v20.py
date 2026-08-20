#!/usr/bin/env python3
"""Validate version-20 source/hash authority-binding reconciliation evidence."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

SCHEMA_VERSION = 20
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


def validate_v20(value: Any, label: str = "reconciliation_v20") -> list[str]:
    """Return violations; an empty list means authority reconciliation is valid."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    for key in ("build_label", "source_commit", "authority_id", "authority_digest", "reconciliation_id"):
        if not _text(value.get(key)):
            errors.append(f"{label}.{key} is required")
    if _text(value.get("authority_digest")) and not _digest(value["authority_digest"]):
        errors.append(f"{label}.authority_digest must be a 64-character hex digest")
    authority = value.get("authority")
    _status(authority, f"{label}.authority", errors)
    if isinstance(authority, dict) and authority.get("status") == "PASS":
        if authority.get("authority_id") != value.get("authority_id"):
            errors.append(f"{label}.authority.authority_id must match authority_id")
        if authority.get("source_commit") != value.get("source_commit"):
            errors.append(f"{label}.authority.source_commit must match source_commit")
        if authority.get("digest") != value.get("authority_digest"):
            errors.append(f"{label}.authority.digest must match authority_digest")
    reconciliation = value.get("reconciliation")
    _status(reconciliation, f"{label}.reconciliation", errors)
    if isinstance(reconciliation, dict) and reconciliation.get("status") == "PASS":
        for key in ("authority_id", "reconciliation_id"):
            if reconciliation.get(key) != value.get(key):
                errors.append(f"{label}.reconciliation.{key} must match {key}")
        if reconciliation.get("source_commit") != value.get("source_commit"):
            errors.append(f"{label}.reconciliation.source_commit must match source_commit")
        if reconciliation.get("digest") != value.get("authority_digest"):
            errors.append(f"{label}.reconciliation.digest must match authority_digest")
        if reconciliation.get("bindings_match") is not True:
            errors.append(f"{label}.reconciliation.bindings_match must be true when status is PASS")
    review = value.get("review")
    _status(review, f"{label}.review", errors)
    if isinstance(review, dict) and review.get("status") == "PASS":
        for key in ("owner", "reviewed_at"):
            if not _text(review.get(key)):
                errors.append(f"{label}.review.{key} is required when status is PASS")
        if review.get("reconciliation_id") != value.get("reconciliation_id"):
            errors.append(f"{label}.review.reconciliation_id must match reconciliation_id")
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
    errors = validate_v20(json.loads(args.record.read_text(encoding="utf-8")))
    if errors:
        print("SOURCE_HASH_AUTHORITY_BINDING_RECONCILIATION_V20_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("SOURCE_HASH_AUTHORITY_BINDING_RECONCILIATION_V20_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
