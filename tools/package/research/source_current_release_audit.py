#!/usr/bin/env python3
"""Validate a recorded source-current package release audit without lookup."""

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
    status = record.get("status")
    if status not in STATES:
        errors.append(f"{label}.status is invalid")
        return
    if status == "PASS" and not _text(record.get("evidence")):
        errors.append(f"{label}.evidence is required when status is PASS")
    if status in {"NOT_RUN", "UNKNOWN"} and record.get("evidence") is not None:
        errors.append(f"{label}.evidence must be null when status is {status}")


def validate_audit(value: Any, label: str = "audit") -> list[str]:
    """Return violations; an empty list means the source-current audit is valid."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    for key in ("release_label", "source_commit", "artifact_label"):
        if not _text(value.get(key)):
            errors.append(f"{label}.{key} is required")

    source = value.get("source_snapshot")
    _status(source, f"{label}.source_snapshot", errors)
    if isinstance(source, dict) and source.get("status") == "PASS":
        if source.get("commit") != value.get("source_commit"):
            errors.append(f"{label}.source_snapshot.commit must match source_commit")
        if source.get("working_tree_clean") is not True:
            errors.append(f"{label}.source_snapshot.working_tree_clean must be true when status is PASS")

    package = value.get("package_snapshot")
    _status(package, f"{label}.package_snapshot", errors)
    if isinstance(package, dict) and package.get("status") == "PASS":
        if package.get("artifact_label") != value.get("artifact_label"):
            errors.append(f"{label}.package_snapshot.artifact_label must match artifact_label")
        if package.get("built_from_commit") != value.get("source_commit"):
            errors.append(f"{label}.package_snapshot.built_from_commit must match source_commit")

    stale = value.get("stale_evidence")
    _status(stale, f"{label}.stale_evidence", errors)
    if isinstance(stale, dict) and stale.get("status") == "PASS":
        if stale.get("stale_artifacts") != 0:
            errors.append(f"{label}.stale_evidence.stale_artifacts must be 0 when status is PASS")
        if stale.get("historical_records_excluded") is not True:
            errors.append(f"{label}.stale_evidence.historical_records_excluded must be true when status is PASS")

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
    errors = validate_audit(json.loads(args.record.read_text(encoding="utf-8")))
    if errors:
        print("SOURCE_CURRENT_RELEASE_AUDIT_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("SOURCE_CURRENT_RELEASE_AUDIT_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
