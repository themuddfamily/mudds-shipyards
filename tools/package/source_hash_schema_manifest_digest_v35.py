#!/usr/bin/env python3
"""Validate version-35 source/hash schema and manifest digest evidence."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

SCHEMA_VERSION = 35
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


def validate_v35(value: Any, label: str = "manifest_v35") -> list[str]:
    """Return violations; an empty list means schema/manifest evidence is valid."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    for key in ("build_label", "source_commit", "manifest_version", "manifest_id", "manifest_digest"):
        if not _text(value.get(key)):
            errors.append(f"{label}.{key} is required")
    if _text(value.get("manifest_digest")) and not _digest(value["manifest_digest"]):
        errors.append(f"{label}.manifest_digest must be a 64-character hex digest")
    manifest = value.get("manifest")
    _status(manifest, f"{label}.manifest", errors)
    if isinstance(manifest, dict) and manifest.get("status") == "PASS":
        if manifest.get("manifest_version") != value.get("manifest_version"):
            errors.append(f"{label}.manifest.manifest_version must match manifest_version")
        if manifest.get("manifest_id") != value.get("manifest_id"):
            errors.append(f"{label}.manifest.manifest_id must match manifest_id")
        if manifest.get("digest") != value.get("manifest_digest"):
            errors.append(f"{label}.manifest.digest must match manifest_digest")
        if manifest.get("schema_version") != value.get("schema_version"):
            errors.append(f"{label}.manifest.schema_version must match schema_version")
    audit = value.get("audit")
    _status(audit, f"{label}.audit", errors)
    if isinstance(audit, dict) and audit.get("status") == "PASS":
        if audit.get("manifest_id") != value.get("manifest_id") or audit.get("manifest_version") != value.get("manifest_version"):
            errors.append(f"{label}.audit manifest identity must match declared values")
        if audit.get("digest_matches") is not True:
            errors.append(f"{label}.audit.digest_matches must be true when status is PASS")
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
    errors = validate_v35(json.loads(args.record.read_text(encoding="utf-8")))
    if errors:
        print("SOURCE_HASH_SCHEMA_MANIFEST_DIGEST_V35_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("SOURCE_HASH_SCHEMA_MANIFEST_DIGEST_V35_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
