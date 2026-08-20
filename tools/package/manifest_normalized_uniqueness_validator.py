#!/usr/bin/env python3
"""Validate canonical path uniqueness in a recorded package manifest."""

from __future__ import annotations

import argparse
import json
import posixpath
from pathlib import Path
from typing import Any

SCHEMA_VERSION = 1
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


def validate_uniqueness(value: Any, label: str = "uniqueness") -> list[str]:
    """Return violations; an empty list means canonical paths are unique."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    for key in ("build_label", "manifest_path"):
        if not _text(value.get(key)):
            errors.append(f"{label}.{key} is required")
    entries = value.get("entries")
    if not isinstance(entries, list) or not entries:
        errors.append(f"{label}.entries must be a non-empty list")
        entries = []
    canonical: set[str] = set()
    for index, entry in enumerate(entries):
        prefix = f"{label}.entries[{index}]"
        if not isinstance(entry, dict):
            errors.append(f"{prefix} must be an object")
            continue
        raw = entry.get("path")
        if not _text(raw):
            errors.append(f"{prefix}.path is required")
            continue
        normalized = posixpath.normpath(raw.replace("\\", "/"))
        if normalized.startswith("/") or normalized == ".." or normalized.startswith("../"):
            errors.append(f"{prefix}.path must resolve to a relative path")
        if normalized in canonical:
            errors.append(f"{prefix}.path must be unique after normalization")
        canonical.add(normalized)
    audit = value.get("audit")
    _status(audit, f"{label}.audit", errors)
    if isinstance(audit, dict) and audit.get("status") == "PASS" and audit.get("duplicate_count") != 0:
        errors.append(f"{label}.audit.duplicate_count must be 0 when status is PASS")
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
    errors = validate_uniqueness(json.loads(args.record.read_text(encoding="utf-8")))
    if errors:
        print("MANIFEST_NORMALIZED_UNIQUENESS_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("MANIFEST_NORMALIZED_UNIQUENESS_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
