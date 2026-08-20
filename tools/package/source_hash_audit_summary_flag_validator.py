#!/usr/bin/env python3
"""Validate summarized source/hash audit flags and counts."""

from __future__ import annotations

import argparse
import json
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
    state = record.get("status")
    if state not in STATES:
        errors.append(f"{label}.status is invalid")
        return
    if state == "PASS" and not _text(record.get("evidence")):
        errors.append(f"{label}.evidence is required when status is PASS")
    if state in {"NOT_RUN", "UNKNOWN"} and record.get("evidence") is not None:
        errors.append(f"{label}.evidence must be null when status is {state}")
    if state in {"FAIL", "UNKNOWN"} and not _text(record.get("reason")):
        errors.append(f"{label}.reason is required when status is {state}")


def validate_summary(value: Any, label: str = "summary") -> list[str]:
    """Return violations; an empty list means the summary flags are valid."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    for key in ("build_label", "source_commit", "summary_label"):
        if not _text(value.get(key)):
            errors.append(f"{label}.{key} is required")
    checks = value.get("checks")
    if not isinstance(checks, list) or not checks:
        errors.append(f"{label}.checks must be a non-empty list")
        checks = []
    names: set[str] = set()
    passed = 0
    for index, check in enumerate(checks):
        prefix = f"{label}.checks[{index}]"
        _status(check, prefix, errors)
        if not isinstance(check, dict):
            continue
        name = check.get("name")
        if not _text(name):
            errors.append(f"{prefix}.name is required")
        elif name in names:
            errors.append(f"{prefix}.name must be unique")
        else:
            names.add(name)
        if check.get("status") == "PASS":
            passed += 1
    for key in ("total_checks", "passed_checks"):
        if not isinstance(value.get(key), int) or value[key] < 0:
            errors.append(f"{label}.{key} must be a non-negative integer")
    if isinstance(value.get("total_checks"), int) and value["total_checks"] != len(checks):
        errors.append(f"{label}.total_checks must equal checks count")
    if isinstance(value.get("passed_checks"), int) and value["passed_checks"] != passed:
        errors.append(f"{label}.passed_checks must equal passing checks")
    if value.get("complete") is True and passed != len(checks):
        errors.append(f"{label}.complete requires every check to PASS")
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
    errors = validate_summary(json.loads(args.record.read_text(encoding="utf-8")))
    if errors:
        print("SOURCE_HASH_AUDIT_SUMMARY_FLAGS_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("SOURCE_HASH_AUDIT_SUMMARY_FLAGS_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
