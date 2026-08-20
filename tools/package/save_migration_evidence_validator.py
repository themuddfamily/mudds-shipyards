#!/usr/bin/env python3
"""Validate recorded save-schema migration evidence without running migrations."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

SCHEMA_VERSION = 1
STATUSES = {"PASS", "FAIL", "NOT_RUN", "UNKNOWN"}


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


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


def validate_migrations(value: Any, label: str = "migrations") -> list[str]:
    """Return violations; an empty list means the migration record is valid."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    for key in ("release_version", "build_label", "source_commit"):
        if not _text(value.get(key)):
            errors.append(f"{label}.{key} is required")
    if not isinstance(value.get("target_schema"), int) or value.get("target_schema", -1) < 0:
        errors.append(f"{label}.target_schema must be a non-negative integer")

    records = value.get("migrations")
    if not isinstance(records, list) or not records:
        errors.append(f"{label}.migrations must be a non-empty list")
        records = []
    identities: set[tuple[int, int]] = set()
    for index, migration in enumerate(records):
        prefix = f"{label}.migrations[{index}]"
        _status(migration, prefix, errors)
        if not isinstance(migration, dict):
            continue
        start, end = migration.get("from_schema"), migration.get("to_schema")
        if not isinstance(start, int) or start < 0:
            errors.append(f"{prefix}.from_schema must be a non-negative integer")
        if not isinstance(end, int) or end < 0:
            errors.append(f"{prefix}.to_schema must be a non-negative integer")
        if isinstance(start, int) and isinstance(end, int):
            identity = (start, end)
            if identity in identities:
                errors.append(f"{prefix} schema transition must be unique")
            identities.add(identity)
            if start == end:
                errors.append(f"{prefix} schema transition must change schema")
            if migration.get("status") == "PASS" and end != start + 1:
                errors.append(f"{prefix}.to_schema must be exactly from_schema + 1 when status is PASS")

    if isinstance(value.get("target_schema"), int) and records:
        passed = [m for m in records if isinstance(m, dict) and m.get("status") == "PASS"]
        if passed and passed[-1].get("to_schema") != value["target_schema"]:
            errors.append(f"{label}.target_schema must match the final passed migration")

    execution = value.get("migration_execution")
    _status(execution, f"{label}.migration_execution", errors)
    if isinstance(execution, dict) and execution.get("status") in {"NOT_RUN", "UNKNOWN"}:
        for key in ("platform", "save_path", "evidence_path"):
            if execution.get(key) is not None:
                errors.append(f"{label}.migration_execution.{key} must be null when status is {execution['status']}")
    if value.get("save_mutated") is not False:
        errors.append(f"{label}.save_mutated must be false")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("record", type=Path)
    args = parser.parse_args(argv)
    errors = validate_migrations(json.loads(args.record.read_text(encoding="utf-8")))
    if errors:
        print("SAVE_MIGRATION_EVIDENCE_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("SAVE_MIGRATION_EVIDENCE_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
