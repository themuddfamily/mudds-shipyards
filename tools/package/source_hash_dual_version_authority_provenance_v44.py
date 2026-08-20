#!/usr/bin/env python3
"""Validate version-44 source/hash authority and provenance dual-version evidence."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

SCHEMA_VERSION = 44
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


def validate_v44(value: Any, label: str = "dual_version_v44") -> list[str]:
    """Return violations; an empty list means dual-version evidence is valid."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    for key in ("build_label", "source_commit", "source_version", "package_version", "authority_id", "provenance_id", "link_id"):
        if not _text(value.get(key)):
            errors.append(f"{label}.{key} is required")

    authority = value.get("authority")
    _status(authority, f"{label}.authority", errors)
    if isinstance(authority, dict) and authority.get("status") == "PASS":
        for key in ("authority_id", "source_commit", "source_version", "package_version"):
            if authority.get(key) != value.get(key):
                errors.append(f"{label}.authority.{key} must match {key}")

    provenance = value.get("provenance")
    _status(provenance, f"{label}.provenance", errors)
    if isinstance(provenance, dict) and provenance.get("status") == "PASS":
        for key in ("provenance_id", "source_commit", "source_version", "package_version"):
            if provenance.get(key) != value.get(key):
                errors.append(f"{label}.provenance.{key} must match {key}")

    link = value.get("link")
    _status(link, f"{label}.link", errors)
    if isinstance(link, dict) and link.get("status") == "PASS":
        for key in ("link_id", "authority_id", "provenance_id", "source_commit", "source_version", "package_version"):
            if link.get(key) != value.get(key):
                errors.append(f"{label}.link.{key} must match {key}")
        if link.get("linked") is not True:
            errors.append(f"{label}.link.linked must be true when status is PASS")

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
    errors = validate_v44(json.loads(args.record.read_text(encoding="utf-8")))
    if errors:
        print("SOURCE_HASH_DUAL_VERSION_AUTHORITY_PROVENANCE_V44_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("SOURCE_HASH_DUAL_VERSION_AUTHORITY_PROVENANCE_V44_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
