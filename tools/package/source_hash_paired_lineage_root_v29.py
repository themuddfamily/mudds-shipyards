#!/usr/bin/env python3
"""Validate version-29 source/hash paired lineage-root evidence."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

SCHEMA_VERSION = 29
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


def validate_v29(value: Any, label: str = "root_v29") -> list[str]:
    """Return violations; an empty list means lineage-root evidence is valid."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    for key in ("build_label", "source_commit", "source_digest", "artifact_digest", "root_id", "root_digest"):
        if not _text(value.get(key)):
            errors.append(f"{label}.{key} is required")
    for key in ("source_digest", "artifact_digest", "root_digest"):
        if _text(value.get(key)) and not _digest(value[key]):
            errors.append(f"{label}.{key} must be a 64-character hex digest")
    root = value.get("root")
    _status(root, f"{label}.root", errors)
    if isinstance(root, dict) and root.get("status") == "PASS":
        if root.get("root_id") != value.get("root_id"):
            errors.append(f"{label}.root.root_id must match root_id")
        if root.get("source_commit") != value.get("source_commit"):
            errors.append(f"{label}.root.source_commit must match source_commit")
        if root.get("digest") != value.get("root_digest"):
            errors.append(f"{label}.root.digest must match root_digest")
    pair = value.get("pair")
    _status(pair, f"{label}.pair", errors)
    if isinstance(pair, dict) and pair.get("status") == "PASS":
        if pair.get("source_digest") != value.get("source_digest") or pair.get("artifact_digest") != value.get("artifact_digest"):
            errors.append(f"{label}.pair digests must match declared digests")
        if pair.get("root_id") != value.get("root_id") or pair.get("root_digest") != value.get("root_digest"):
            errors.append(f"{label}.pair root identity must match declared root")
        if pair.get("rooted") is not True:
            errors.append(f"{label}.pair.rooted must be true when status is PASS")
    reconciliation = value.get("reconciliation")
    _status(reconciliation, f"{label}.reconciliation", errors)
    if isinstance(reconciliation, dict) and reconciliation.get("status") == "PASS":
        if reconciliation.get("root_id") != value.get("root_id"):
            errors.append(f"{label}.reconciliation.root_id must match root_id")
        if reconciliation.get("root_digest") != value.get("root_digest"):
            errors.append(f"{label}.reconciliation.root_digest must match root_digest")
        if reconciliation.get("consistent") is not True:
            errors.append(f"{label}.reconciliation.consistent must be true when status is PASS")
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
    errors = validate_v29(json.loads(args.record.read_text(encoding="utf-8")))
    if errors:
        print("SOURCE_HASH_PAIRED_LINEAGE_ROOT_V29_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("SOURCE_HASH_PAIRED_LINEAGE_ROOT_V29_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
