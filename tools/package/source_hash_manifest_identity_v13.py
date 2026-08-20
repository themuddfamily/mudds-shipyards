#!/usr/bin/env python3
"""Validate version-13 source/hash manifest identity evidence."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

SCHEMA_VERSION = 13
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
    status = record.get("status")
    if status not in STATES:
        errors.append(f"{label}.status is invalid")
        return
    if status == "PASS" and not _text(record.get("evidence")):
        errors.append(f"{label}.evidence is required when status is PASS")
    if status in {"NOT_RUN", "UNKNOWN"} and record.get("evidence") is not None:
        errors.append(f"{label}.evidence must be null when status is {status}")


def validate_v13(value: Any, label: str = "identity_v13") -> list[str]:
    """Return violations; an empty list means the v13 identity is valid."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    for key in ("build_label", "source_commit", "manifest_id", "root_digest"):
        if not _text(value.get(key)):
            errors.append(f"{label}.{key} is required")
    if _text(value.get("root_digest")) and not _digest(value["root_digest"]):
        errors.append(f"{label}.root_digest must be a 64-character hex digest")
    identity = value.get("identity")
    _status(identity, f"{label}.identity", errors)
    if isinstance(identity, dict) and identity.get("status") == "PASS":
        for key in ("manifest_id", "source_commit", "root_digest"):
            if identity.get(key) != value.get(key):
                errors.append(f"{label}.identity.{key} must match {key}")
        if identity.get("stable") is not True:
            errors.append(f"{label}.identity.stable must be true when status is PASS")
    entries = value.get("entries")
    if not isinstance(entries, list) or not entries:
        errors.append(f"{label}.entries must be a non-empty list")
        entries = []
    ids: set[str] = set()
    for index, entry in enumerate(entries):
        prefix = f"{label}.entries[{index}]"
        if not isinstance(entry, dict):
            errors.append(f"{prefix} must be an object")
            continue
        entry_id = entry.get("entry_id")
        if not _text(entry_id):
            errors.append(f"{prefix}.entry_id is required")
        elif entry_id in ids:
            errors.append(f"{prefix}.entry_id must be unique")
        else:
            ids.add(entry_id)
        for key in ("manifest_id", "source_commit"):
            if entry.get(key) != value.get(key):
                errors.append(f"{prefix}.{key} must match {key}")
        if not _digest(entry.get("digest")):
            errors.append(f"{prefix}.digest must be a 64-character hex digest")
    audit = value.get("audit")
    _status(audit, f"{label}.audit", errors)
    if isinstance(audit, dict) and audit.get("status") == "PASS":
        if audit.get("entry_count") != len(entries):
            errors.append(f"{label}.audit.entry_count must equal entries count")
        if audit.get("identity_matches") is not True:
            errors.append(f"{label}.audit.identity_matches must be true when status is PASS")
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
    errors = validate_v13(json.loads(args.record.read_text(encoding="utf-8")))
    if errors:
        print("SOURCE_HASH_MANIFEST_IDENTITY_V13_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("SOURCE_HASH_MANIFEST_IDENTITY_V13_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
