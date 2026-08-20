#!/usr/bin/env python3
"""Validate a package test-matrix evidence rollup without running packages."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

SCHEMA_VERSION = 1
STATUSES = {"PASS", "FAIL", "NOT_RUN", "UNKNOWN"}
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
    if state not in STATUSES:
        errors.append(f"{label}.status is invalid")
        return
    if state == "PASS" and not _text(record.get("evidence")):
        errors.append(f"{label}.evidence is required when status is PASS")
    if state in {"NOT_RUN", "UNKNOWN"} and record.get("evidence") is not None:
        errors.append(f"{label}.evidence must be null when status is {state}")


def validate_matrix(value: Any, label: str = "matrix") -> list[str]:
    """Return violations; an empty list means the matrix rollup is valid."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    for key in ("build_label", "source_commit", "artifact_sha256"):
        if not _text(value.get(key)):
            errors.append(f"{label}.{key} is required")
    if value.get("artifact_sha256") is not None and not _digest(value.get("artifact_sha256")):
        errors.append(f"{label}.artifact_sha256 must be a 64-character hex digest")

    rows = value.get("rows")
    if not isinstance(rows, list) or not rows:
        errors.append(f"{label}.rows must be a non-empty list")
    else:
        seen: set[str] = set()
        for index, row in enumerate(rows):
            prefix = f"{label}.rows[{index}]"
            _status(row, prefix, errors)
            if not isinstance(row, dict):
                continue
            name = row.get("name")
            if not _text(name):
                errors.append(f"{prefix}.name is required")
            elif name in seen:
                errors.append(f"{prefix}.name must be unique")
            else:
                seen.add(name)
            for key in ("source_commit", "artifact_sha256"):
                if row.get(key) != value.get(key):
                    errors.append(f"{prefix}.{key} must match matrix.{key}")
            if row.get("status") == "PASS" and not isinstance(row.get("assertions"), int):
                errors.append(f"{prefix}.assertions must be an integer when status is PASS")
            if isinstance(row.get("assertions"), int) and row["assertions"] < 0:
                errors.append(f"{prefix}.assertions must be non-negative")

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
    errors = validate_matrix(json.loads(args.record.read_text(encoding="utf-8")))
    if errors:
        print("PACKAGE_MATRIX_ROLLUP_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PACKAGE_MATRIX_ROLLUP_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
