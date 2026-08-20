#!/usr/bin/env python3
"""Validate clean-directory embedded-PCK startup evidence without running it."""

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
    evidence = record.get("evidence")
    if state == "PASS" and not _text(evidence):
        errors.append(f"{label}.evidence is required when status is PASS")
    if state in {"NOT_RUN", "UNKNOWN"} and evidence is not None:
        errors.append(f"{label}.evidence must be null when status is {state}")


def validate_startup(value: Any, label: str = "startup") -> list[str]:
    """Return violations; an empty list means the startup record is valid."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    for key in ("build_label", "source_commit", "artifact_path"):
        if not _text(value.get(key)):
            errors.append(f"{label}.{key} is required")

    clean = value.get("clean_directory")
    _status(clean, f"{label}.clean_directory", errors)
    if isinstance(clean, dict) and clean.get("status") == "PASS":
        if clean.get("created_before_run") is not True:
            errors.append(f"{label}.clean_directory.created_before_run must be true when status is PASS")
        if clean.get("user_data_present") is not False:
            errors.append(f"{label}.clean_directory.user_data_present must be false when status is PASS")

    embedded = value.get("embedded_pck_startup")
    _status(embedded, f"{label}.embedded_pck_startup", errors)
    if isinstance(embedded, dict) and embedded.get("status") == "PASS":
        if embedded.get("embedded") is not True:
            errors.append(f"{label}.embedded_pck_startup.embedded must be true when status is PASS")
        if not isinstance(embedded.get("exit_code"), int) or embedded["exit_code"] != 0:
            errors.append(f"{label}.embedded_pck_startup.exit_code must be 0 when status is PASS")
        if not isinstance(embedded.get("frames"), int) or embedded["frames"] <= 0:
            errors.append(f"{label}.embedded_pck_startup.frames must be positive when status is PASS")

    isolation = value.get("user_data_isolation")
    _status(isolation, f"{label}.user_data_isolation", errors)
    if isinstance(isolation, dict) and isolation.get("status") == "PASS":
        if isolation.get("before_digest") != isolation.get("after_digest"):
            errors.append(f"{label}.user_data_isolation.before_digest must match after_digest when status is PASS")
        if not _text(isolation.get("before_digest")):
            errors.append(f"{label}.user_data_isolation.before_digest is required when status is PASS")

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
    errors = validate_startup(json.loads(args.record.read_text(encoding="utf-8")))
    if errors:
        print("CLEAN_DIRECTORY_STARTUP_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("CLEAN_DIRECTORY_STARTUP_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
