#!/usr/bin/env python3
"""Validate recorded desktop platform compatibility evidence without running it."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

SCHEMA_VERSION = 1
STATES = {"PASS", "FAIL", "NOT_RUN", "UNKNOWN"}


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _state(record: Any, label: str, errors: list[str]) -> None:
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


def validate_platforms(value: Any, label: str = "platforms") -> list[str]:
    """Return violations; an empty list means the platform rollup is valid."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    for key in ("build_label", "source_commit", "artifact_path"):
        if not _text(value.get(key)):
            errors.append(f"{label}.{key} is required")

    rows = value.get("platforms")
    if not isinstance(rows, list) or not rows:
        errors.append(f"{label}.platforms must be a non-empty list")
    else:
        names: set[str] = set()
        for index, row in enumerate(rows):
            prefix = f"{label}.platforms[{index}]"
            _state(row, prefix, errors)
            if not isinstance(row, dict):
                continue
            name = row.get("name")
            if not _text(name):
                errors.append(f"{prefix}.name is required")
            elif name in names:
                errors.append(f"{prefix}.name must be unique")
            else:
                names.add(name)
            for key in ("os", "architecture", "renderer"):
                if not _text(row.get(key)):
                    errors.append(f"{prefix}.{key} is required")
            if row.get("status") == "PASS" and not isinstance(row.get("assertions"), int):
                errors.append(f"{prefix}.assertions must be an integer when status is PASS")

    native = value.get("native_execution")
    _state(native, f"{label}.native_execution", errors)
    if isinstance(native, dict) and native.get("status") in {"NOT_RUN", "UNKNOWN"}:
        for key in ("platform", "hardware", "evidence_path"):
            if native.get(key) is not None:
                errors.append(f"{label}.native_execution.{key} must be null when status is {native['status']}")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("record", type=Path)
    args = parser.parse_args(argv)
    errors = validate_platforms(json.loads(args.record.read_text(encoding="utf-8")))
    if errors:
        print("DESKTOP_PLATFORM_ROLLUP_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("DESKTOP_PLATFORM_ROLLUP_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
