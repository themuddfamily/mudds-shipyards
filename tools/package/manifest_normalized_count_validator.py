#!/usr/bin/env python3
"""Validate normalized manifest path and hash counts from recorded metadata."""

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


def validate_counts(value: Any, label: str = "counts") -> list[str]:
    """Return violations; an empty list means normalized path counts are valid."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    for key in ("build_label", "source_commit"):
        if not _text(value.get(key)):
            errors.append(f"{label}.{key} is required")
    records = value.get("entries")
    if not isinstance(records, list) or not records:
        errors.append(f"{label}.entries must be a non-empty list")
        records = []
    normalized: set[str] = set()
    for index, entry in enumerate(records):
        prefix = f"{label}.entries[{index}]"
        if not isinstance(entry, dict):
            errors.append(f"{prefix} must be an object")
            continue
        path = entry.get("canonical_path")
        if not _text(path):
            errors.append(f"{prefix}.canonical_path is required")
        elif path in normalized:
            errors.append(f"{prefix}.canonical_path must be unique")
        else:
            normalized.add(path)
        if not _digest(entry.get("sha256")):
            errors.append(f"{prefix}.sha256 must be a 64-character hex digest")
    for key in ("declared_count", "observed_count", "normalized_count", "hashed_count"):
        if not isinstance(value.get(key), int) or value[key] < 0:
            errors.append(f"{label}.{key} must be a non-negative integer")
    if isinstance(value.get("observed_count"), int) and value["observed_count"] != len(records):
        errors.append(f"{label}.observed_count must equal entries count")
    if isinstance(value.get("normalized_count"), int) and value["normalized_count"] != len(normalized):
        errors.append(f"{label}.normalized_count must equal unique path count")
    if isinstance(value.get("hashed_count"), int) and value["hashed_count"] != len(records):
        errors.append(f"{label}.hashed_count must equal entries count")
    if isinstance(value.get("declared_count"), int) and value["declared_count"] != len(records):
        errors.append(f"{label}.declared_count must equal entries count")

    audit = value.get("audit")
    _status(audit, f"{label}.audit", errors)
    if isinstance(audit, dict) and audit.get("status") == "PASS" and audit.get("counts_match") is not True:
        errors.append(f"{label}.audit.counts_match must be true when status is PASS")
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
    errors = validate_counts(json.loads(args.record.read_text(encoding="utf-8")))
    if errors:
        print("MANIFEST_NORMALIZED_COUNT_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("MANIFEST_NORMALIZED_COUNT_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
