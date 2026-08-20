#!/usr/bin/env python3
"""Validate normalized path/source/hash audit counts from recorded metadata."""

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
    state = record.get("status")
    if state not in STATES:
        errors.append(f"{label}.status is invalid")
        return
    if state == "PASS" and not _text(record.get("evidence")):
        errors.append(f"{label}.evidence is required when status is PASS")
    if state in {"NOT_RUN", "UNKNOWN"} and record.get("evidence") is not None:
        errors.append(f"{label}.evidence must be null when status is {state}")


def validate_counts(value: Any, label: str = "counts") -> list[str]:
    """Return violations; an empty list means the audit counts are valid."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    for key in ("build_label", "source_commit"):
        if not _text(value.get(key)):
            errors.append(f"{label}.{key} is required")
    entries = value.get("entries")
    if not isinstance(entries, list) or not entries:
        errors.append(f"{label}.entries must be a non-empty list")
        entries = []
    paths: set[str] = set()
    source_count = hash_count = 0
    for index, entry in enumerate(entries):
        prefix = f"{label}.entries[{index}]"
        if not isinstance(entry, dict):
            errors.append(f"{prefix} must be an object")
            continue
        path = entry.get("normalized_path")
        if not _text(path):
            errors.append(f"{prefix}.normalized_path is required")
        elif path in paths:
            errors.append(f"{prefix}.normalized_path must be unique")
        else:
            paths.add(path)
        if entry.get("source_commit") != value.get("source_commit"):
            errors.append(f"{prefix}.source_commit must match source_commit")
        else:
            source_count += 1
        if _digest(entry.get("sha256")):
            hash_count += 1
        else:
            errors.append(f"{prefix}.sha256 must be a 64-character hex digest")
    for key, expected in (("path_count", len(paths)), ("source_count", source_count), ("hash_count", hash_count)):
        if not isinstance(value.get(key), int) or value[key] != expected:
            errors.append(f"{label}.{key} must equal audited count")
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
        print("NORMALIZED_PATH_SOURCE_HASH_COUNT_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("NORMALIZED_PATH_SOURCE_HASH_COUNT_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
