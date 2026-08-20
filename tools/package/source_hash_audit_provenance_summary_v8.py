#!/usr/bin/env python3
"""Validate version-8 source/hash audit provenance summaries."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

SCHEMA_VERSION = 8
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


def validate_v8(value: Any, label: str = "provenance_v8") -> list[str]:
    """Return violations; an empty list means the v8 summary is valid."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    for key in ("build_label", "source_commit", "summary_digest", "provenance_id"):
        if not _text(value.get(key)):
            errors.append(f"{label}.{key} is required")
    if _text(value.get("summary_digest")) and not _digest(value["summary_digest"]):
        errors.append(f"{label}.summary_digest must be a 64-character hex digest")
    provenance = value.get("provenance")
    _status(provenance, f"{label}.provenance", errors)
    if isinstance(provenance, dict) and provenance.get("status") == "PASS":
        if provenance.get("provenance_id") != value.get("provenance_id"):
            errors.append(f"{label}.provenance.provenance_id must match provenance_id")
        if provenance.get("source_commit") != value.get("source_commit"):
            errors.append(f"{label}.provenance.source_commit must match source_commit")
        if not _text(provenance.get("origin")):
            errors.append(f"{label}.provenance.origin is required when status is PASS")
    digest = value.get("digest")
    _status(digest, f"{label}.digest", errors)
    if isinstance(digest, dict) and digest.get("status") == "PASS":
        if digest.get("observed") != value.get("summary_digest"):
            errors.append(f"{label}.digest.observed must match summary_digest")
        if digest.get("reproducible") is not True:
            errors.append(f"{label}.digest.reproducible must be true when status is PASS")
    review = value.get("review")
    _status(review, f"{label}.review", errors)
    if isinstance(review, dict) and review.get("status") == "PASS":
        for key in ("owner", "reviewed_at"):
            if not _text(review.get(key)):
                errors.append(f"{label}.review.{key} is required when status is PASS")
        if review.get("provenance_id") != value.get("provenance_id"):
            errors.append(f"{label}.review.provenance_id must match provenance_id")
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
    errors = validate_v8(json.loads(args.record.read_text(encoding="utf-8")))
    if errors:
        print("SOURCE_HASH_AUDIT_PROVENANCE_SUMMARY_V8_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("SOURCE_HASH_AUDIT_PROVENANCE_SUMMARY_V8_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
