#!/usr/bin/env python3
"""Validate version-33 source/hash root/authority digest evidence."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

SCHEMA_VERSION = 33
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


def validate_v33(value: Any, label: str = "versioned_v33") -> list[str]:
    """Return violations; an empty list means versioned authority evidence is valid."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    for key in ("build_label", "source_commit", "record_version", "root_id", "root_digest", "authority_id", "authority_digest"):
        if not _text(value.get(key)):
            errors.append(f"{label}.{key} is required")
    for key in ("root_digest", "authority_digest"):
        if _text(value.get(key)) and not _digest(value[key]):
            errors.append(f"{label}.{key} must be a 64-character hex digest")
    root = value.get("root")
    _status(root, f"{label}.root", errors)
    if isinstance(root, dict) and root.get("status") == "PASS":
        if root.get("record_version") != value.get("record_version"):
            errors.append(f"{label}.root.record_version must match record_version")
        if root.get("root_id") != value.get("root_id") or root.get("digest") != value.get("root_digest"):
            errors.append(f"{label}.root identity must match declared root")
    authority = value.get("authority")
    _status(authority, f"{label}.authority", errors)
    if isinstance(authority, dict) and authority.get("status") == "PASS":
        if authority.get("record_version") != value.get("record_version"):
            errors.append(f"{label}.authority.record_version must match record_version")
        if authority.get("authority_id") != value.get("authority_id") or authority.get("digest") != value.get("authority_digest"):
            errors.append(f"{label}.authority identity must match declared authority")
    pair = value.get("pair")
    _status(pair, f"{label}.pair", errors)
    if isinstance(pair, dict) and pair.get("status") == "PASS":
        if pair.get("record_version") != value.get("record_version"):
            errors.append(f"{label}.pair.record_version must match record_version")
        if pair.get("root_id") != value.get("root_id") or pair.get("authority_id") != value.get("authority_id"):
            errors.append(f"{label}.pair IDs must match declared IDs")
        if pair.get("reconciled") is not True:
            errors.append(f"{label}.pair.reconciled must be true when status is PASS")
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
    errors = validate_v33(json.loads(args.record.read_text(encoding="utf-8")))
    if errors:
        print("SOURCE_HASH_VERSIONED_ROOT_AUTHORITY_DIGEST_V33_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("SOURCE_HASH_VERSIONED_ROOT_AUTHORITY_DIGEST_V33_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
