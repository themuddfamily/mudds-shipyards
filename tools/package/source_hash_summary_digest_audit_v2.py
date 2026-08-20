#!/usr/bin/env python3
"""Validate version-2 source/hash summary digest audit evidence."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

SCHEMA_VERSION = 2
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


def validate_v2(value: Any, label: str = "audit_v2") -> list[str]:
    """Return violations; an empty list means the v2 audit is valid."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    for key in ("build_label", "source_commit", "summary_digest", "audit_id"):
        if not _text(value.get(key)):
            errors.append(f"{label}.{key} is required")
    if _text(value.get("summary_digest")) and not _digest(value["summary_digest"]):
        errors.append(f"{label}.summary_digest must be a 64-character hex digest")
    audit = value.get("digest_audit")
    _status(audit, f"{label}.digest_audit", errors)
    if isinstance(audit, dict) and audit.get("status") == "PASS":
        if audit.get("source_bound") is not True or audit.get("digest_reproducible") is not True:
            errors.append(f"{label}.digest_audit source_bound and digest_reproducible must be true when status is PASS")
        if audit.get("observed_digest") != value.get("summary_digest"):
            errors.append(f"{label}.digest_audit.observed_digest must match summary_digest")
    evidence = value.get("evidence_record")
    _status(evidence, f"{label}.evidence_record", errors)
    if isinstance(evidence, dict) and evidence.get("status") == "PASS" and evidence.get("audit_id") != value.get("audit_id"):
        errors.append(f"{label}.evidence_record.audit_id must match audit_id")
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
    errors = validate_v2(json.loads(args.record.read_text(encoding="utf-8")))
    if errors:
        print("SOURCE_HASH_SUMMARY_DIGEST_AUDIT_V2_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("SOURCE_HASH_SUMMARY_DIGEST_AUDIT_V2_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
