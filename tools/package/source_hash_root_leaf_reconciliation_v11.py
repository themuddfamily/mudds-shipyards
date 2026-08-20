#!/usr/bin/env python3
"""Validate version-11 source/hash root and leaf reconciliation evidence."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

SCHEMA_VERSION = 11
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


def validate_v11(value: Any, label: str = "reconciliation_v11") -> list[str]:
    """Return violations; an empty list means root/leaf reconciliation is valid."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    for key in ("build_label", "source_commit", "root_digest", "reconciliation_id"):
        if not _text(value.get(key)):
            errors.append(f"{label}.{key} is required")
    if _text(value.get("root_digest")) and not _digest(value["root_digest"]):
        errors.append(f"{label}.root_digest must be a 64-character hex digest")
    root = value.get("root")
    _status(root, f"{label}.root", errors)
    if isinstance(root, dict) and root.get("status") == "PASS":
        if root.get("digest") != value.get("root_digest"):
            errors.append(f"{label}.root.digest must match root_digest")
        if root.get("source_commit") != value.get("source_commit"):
            errors.append(f"{label}.root.source_commit must match source_commit")
    leaves = value.get("leaves")
    if not isinstance(leaves, list) or not leaves:
        errors.append(f"{label}.leaves must be a non-empty list")
        leaves = []
    ids: set[str] = set()
    for index, leaf in enumerate(leaves):
        prefix = f"{label}.leaves[{index}]"
        if not isinstance(leaf, dict):
            errors.append(f"{prefix} must be an object")
            continue
        leaf_id = leaf.get("leaf_id")
        if not _text(leaf_id):
            errors.append(f"{prefix}.leaf_id is required")
        elif leaf_id in ids:
            errors.append(f"{prefix}.leaf_id must be unique")
        else:
            ids.add(leaf_id)
        if leaf.get("source_commit") != value.get("source_commit"):
            errors.append(f"{prefix}.source_commit must match source_commit")
        if not _digest(leaf.get("digest")):
            errors.append(f"{prefix}.digest must be a 64-character hex digest")
    reconciliation = value.get("reconciliation")
    _status(reconciliation, f"{label}.reconciliation", errors)
    if isinstance(reconciliation, dict) and reconciliation.get("status") == "PASS":
        if reconciliation.get("reconciliation_id") != value.get("reconciliation_id"):
            errors.append(f"{label}.reconciliation.reconciliation_id must match reconciliation_id")
        if reconciliation.get("leaf_count") != len(leaves):
            errors.append(f"{label}.reconciliation.leaf_count must equal leaves count")
        if reconciliation.get("root_matches_leaves") is not True:
            errors.append(f"{label}.reconciliation.root_matches_leaves must be true when status is PASS")
    review = value.get("review")
    _status(review, f"{label}.review", errors)
    if isinstance(review, dict) and review.get("status") == "PASS":
        for key in ("owner", "reviewed_at"):
            if not _text(review.get(key)):
                errors.append(f"{label}.review.{key} is required when status is PASS")
        if review.get("reconciliation_id") != value.get("reconciliation_id"):
            errors.append(f"{label}.review.reconciliation_id must match reconciliation_id")
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
    errors = validate_v11(json.loads(args.record.read_text(encoding="utf-8")))
    if errors:
        print("SOURCE_HASH_ROOT_LEAF_RECONCILIATION_V11_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("SOURCE_HASH_ROOT_LEAF_RECONCILIATION_V11_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
