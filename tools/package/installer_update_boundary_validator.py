#!/usr/bin/env python3
"""Validate installer/update boundary evidence without executing an installer."""

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


def validate_boundary(value: Any, label: str = "boundary") -> list[str]:
    """Return violations; an empty list means the boundary record is valid."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    for key in ("build_label", "source_commit", "from_version", "to_version"):
        if not _text(value.get(key)):
            errors.append(f"{label}.{key} is required")
    if value.get("install_or_update_executed") is not False:
        errors.append(f"{label}.install_or_update_executed must be false")
    if value.get("user_data_mutated") is not False:
        errors.append(f"{label}.user_data_mutated must be false")

    compatibility = value.get("compatibility")
    _status(compatibility, f"{label}.compatibility", errors)
    if isinstance(compatibility, dict) and compatibility.get("status") == "PASS":
        if compatibility.get("save_schema_supported") is not True:
            errors.append(f"{label}.compatibility.save_schema_supported must be true when status is PASS")
        if not _text(compatibility.get("manifest")):
            errors.append(f"{label}.compatibility.manifest is required when status is PASS")

    installer = value.get("installer")
    _status(installer, f"{label}.installer", errors)
    if isinstance(installer, dict) and installer.get("status") in {"NOT_RUN", "UNKNOWN"}:
        for key in ("platform", "command", "evidence_path"):
            if installer.get(key) is not None:
                errors.append(f"{label}.installer.{key} must be null when status is {installer['status']}")
    if isinstance(installer, dict) and installer.get("status") == "PASS" and installer.get("executed") is not False:
        errors.append(f"{label}.installer.executed must be false for evidence-only validation")

    rollback = value.get("rollback")
    _status(rollback, f"{label}.rollback", errors)
    if isinstance(rollback, dict) and rollback.get("status") == "PASS" and rollback.get("reversible") is not True:
        errors.append(f"{label}.rollback.reversible must be true when status is PASS")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("record", type=Path)
    args = parser.parse_args(argv)
    errors = validate_boundary(json.loads(args.record.read_text(encoding="utf-8")))
    if errors:
        print("INSTALLER_UPDATE_BOUNDARY_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("INSTALLER_UPDATE_BOUNDARY_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
