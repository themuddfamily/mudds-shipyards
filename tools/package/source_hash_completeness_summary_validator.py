#!/usr/bin/env python3
"""Validate a recorded source/hash completeness summary."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

SCHEMA_VERSION = 1
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


def validate_summary(value: Any, label: str = "summary") -> list[str]:
    """Return violations; an empty list means the completeness summary is valid."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    for key in ("build_label", "source_commit", "summary_digest"):
        if not _text(value.get(key)):
            errors.append(f"{label}.{key} is required")
    if _text(value.get("summary_digest")) and not _digest(value["summary_digest"]):
        errors.append(f"{label}.summary_digest must be a 64-character hex digest")
    entries = value.get("entries")
    if not isinstance(entries, list) or not entries:
        errors.append(f"{label}.entries must be a non-empty list")
        entries = []
    source_bound = 0
    hashed = 0
    for index, entry in enumerate(entries):
        prefix = f"{label}.entries[{index}]"
        if not isinstance(entry, dict):
            errors.append(f"{prefix} must be an object")
            continue
        if entry.get("source_commit") == value.get("source_commit"):
            source_bound += 1
        else:
            errors.append(f"{prefix}.source_commit must match source_commit")
        if _digest(entry.get("sha256")):
            hashed += 1
        else:
            errors.append(f"{prefix}.sha256 must be a 64-character hex digest")
    for key, expected in (("total_entries", len(entries)), ("source_bound_entries", source_bound), ("hashed_entries", hashed)):
        if value.get(key) != expected:
            errors.append(f"{label}.{key} must equal summary count")
    check = value.get("summary_check")
    _status(check, f"{label}.summary_check", errors)
    if isinstance(check, dict) and check.get("status") == "PASS" and check.get("complete") is not True:
        errors.append(f"{label}.summary_check.complete must be true when status is PASS")
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
    errors = validate_summary(json.loads(args.record.read_text(encoding="utf-8")))
    if errors:
        print("SOURCE_HASH_COMPLETENESS_SUMMARY_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("SOURCE_HASH_COMPLETENESS_SUMMARY_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
