#!/usr/bin/env python3
"""Validate version-18 source/hash completeness and authority digest evidence."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

SCHEMA_VERSION = 18
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


def validate_v18(value: Any, label: str = "authority_v18") -> list[str]:
    """Return violations; an empty list means authority digest evidence is valid."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    for key in ("build_label", "source_commit", "manifest_id", "authority_digest"):
        if not _text(value.get(key)):
            errors.append(f"{label}.{key} is required")
    if _text(value.get("authority_digest")) and not _digest(value["authority_digest"]):
        errors.append(f"{label}.authority_digest must be a 64-character hex digest")
    authority = value.get("authority")
    _status(authority, f"{label}.authority", errors)
    if isinstance(authority, dict) and authority.get("status") == "PASS":
        for key in ("owner", "manifest_id"):
            if not _text(authority.get(key)):
                errors.append(f"{label}.authority.{key} is required when status is PASS")
        if authority.get("manifest_id") != value.get("manifest_id"):
            errors.append(f"{label}.authority.manifest_id must match manifest_id")
        if authority.get("digest") != value.get("authority_digest"):
            errors.append(f"{label}.authority.digest must match authority_digest")
    entries = value.get("entries")
    if not isinstance(entries, list) or not entries:
        errors.append(f"{label}.entries must be a non-empty list")
        entries = []
    complete = 0
    for index, entry in enumerate(entries):
        prefix = f"{label}.entries[{index}]"
        if not isinstance(entry, dict):
            errors.append(f"{prefix} must be an object")
            continue
        if entry.get("source_commit") != value.get("source_commit"):
            errors.append(f"{prefix}.source_commit must match source_commit")
        if entry.get("manifest_id") != value.get("manifest_id"):
            errors.append(f"{prefix}.manifest_id must match manifest_id")
        if _digest(entry.get("digest")):
            complete += 1
        else:
            errors.append(f"{prefix}.digest must be a 64-character hex digest")
    completeness = value.get("completeness")
    _status(completeness, f"{label}.completeness", errors)
    if isinstance(completeness, dict) and completeness.get("status") == "PASS":
        if completeness.get("entry_count") != len(entries):
            errors.append(f"{label}.completeness.entry_count must equal entries count")
        if completeness.get("complete_digest_count") != complete:
            errors.append(f"{label}.completeness.complete_digest_count must equal complete digest count")
        if completeness.get("authority_matches") is not True:
            errors.append(f"{label}.completeness.authority_matches must be true when status is PASS")
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
    errors = validate_v18(json.loads(args.record.read_text(encoding="utf-8")))
    if errors:
        print("SOURCE_HASH_COMPLETENESS_AUTHORITY_V18_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("SOURCE_HASH_COMPLETENESS_AUTHORITY_V18_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
