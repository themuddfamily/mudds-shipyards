#!/usr/bin/env python3
"""Validate completeness claims for normalized source/hash aggregate evidence."""

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


def validate_completeness(value: Any, label: str = "completeness") -> list[str]:
    """Return violations; an empty list means completeness evidence is valid."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    for key in ("build_label", "source_commit", "aggregate_sha256"):
        if not _text(value.get(key)):
            errors.append(f"{label}.{key} is required")
    if _text(value.get("aggregate_sha256")) and not _digest(value["aggregate_sha256"]):
        errors.append(f"{label}.aggregate_sha256 must be a 64-character hex digest")
    entries = value.get("entries")
    if not isinstance(entries, list) or not entries:
        errors.append(f"{label}.entries must be a non-empty list")
        entries = []
    paths: set[str] = set()
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
        if not _digest(entry.get("sha256")):
            errors.append(f"{prefix}.sha256 must be a 64-character hex digest")
    completeness = value.get("coverage")
    _status(completeness, f"{label}.coverage", errors)
    if isinstance(completeness, dict) and completeness.get("status") == "PASS":
        for key in ("all_paths_accounted", "all_sources_bound", "all_hashes_present"):
            if completeness.get(key) is not True:
                errors.append(f"{label}.coverage.{key} must be true when status is PASS")
        if completeness.get("missing_paths") != 0 or completeness.get("missing_hashes") != 0:
            errors.append(f"{label}.coverage missing_paths and missing_hashes must be 0 when status is PASS")
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
    errors = validate_completeness(json.loads(args.record.read_text(encoding="utf-8")))
    if errors:
        print("NORMALIZED_SOURCE_HASH_COMPLETENESS_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("NORMALIZED_SOURCE_HASH_COMPLETENESS_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
