#!/usr/bin/env python3
"""Validate recorded package manifest entry hashes and counts."""

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


def validate_entries(value: Any, label: str = "entries") -> list[str]:
    """Return violations; an empty list means the entry audit is valid."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    for key in ("build_label", "manifest_path"):
        if not _text(value.get(key)):
            errors.append(f"{label}.{key} is required")
    declared = value.get("declared_count")
    if not isinstance(declared, int) or declared <= 0:
        errors.append(f"{label}.declared_count must be positive")
    records = value.get("entries")
    if not isinstance(records, list) or not records:
        errors.append(f"{label}.entries must be a non-empty list")
        records = []
    paths: set[str] = set()
    for index, record in enumerate(records):
        prefix = f"{label}.entries[{index}]"
        if not isinstance(record, dict):
            errors.append(f"{prefix} must be an object")
            continue
        path = record.get("path")
        if not _text(path):
            errors.append(f"{prefix}.path is required")
        elif path in paths:
            errors.append(f"{prefix}.path must be unique")
        else:
            paths.add(path)
        if not _digest(record.get("sha256")):
            errors.append(f"{prefix}.sha256 must be a 64-character hex digest")
    if isinstance(declared, int) and declared != len(records):
        errors.append(f"{label}.declared_count must equal entries count")

    audit = value.get("audit")
    _status(audit, f"{label}.audit", errors)
    if isinstance(audit, dict) and audit.get("status") == "PASS":
        if audit.get("hashed_count") != len(records):
            errors.append(f"{label}.audit.hashed_count must equal entries count")
        if audit.get("missing_hashes") != 0:
            errors.append(f"{label}.audit.missing_hashes must be 0")

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
    errors = validate_entries(json.loads(args.record.read_text(encoding="utf-8")))
    if errors:
        print("MANIFEST_ENTRY_HASH_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("MANIFEST_ENTRY_HASH_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
