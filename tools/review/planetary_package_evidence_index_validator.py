#!/usr/bin/env python3
"""Validate a source/evidence index joining planetary and package artifacts.

The index is an evidence map, not a release sign-off.  It requires explicit
pending states for human/native gates and never treats a path listing as proof
that an artifact was executed or reviewed.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

SCHEMA_VERSION = "planetary_package_evidence_index_v1"
KINDS = {"planetary_source", "planetary_test", "package_manifest", "package_artifact"}
OPEN_STATUSES = {"pending", "not_performed", "unknown"}


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def validate_index(value: Any, label: str = "index") -> list[str]:
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema") != SCHEMA_VERSION:
        errors.append(f"{label}.schema must be {SCHEMA_VERSION}")
    for key in ("source_revision", "owner"):
        if not _text(value.get(key)):
            errors.append(f"{label}.{key} is required")
    entries = value.get("entries")
    if not isinstance(entries, list) or not entries:
        errors.append(f"{label}.entries must contain at least one record")
        entries = []
    seen: set[str] = set()
    for index, entry in enumerate(entries):
        prefix = f"{label}.entries[{index}]"
        if not isinstance(entry, dict):
            errors.append(f"{prefix} must be an object")
            continue
        entry_id = entry.get("id")
        if not _text(entry_id) or entry_id in seen:
            errors.append(f"{prefix}.id must be unique non-empty text")
        seen.add(entry_id)
        if entry.get("kind") not in KINDS:
            errors.append(f"{prefix}.kind is invalid")
        path = entry.get("path")
        if not _text(path) or not path.startswith("res://"):
            errors.append(f"{prefix}.path must be a res:// source path")
        if not _text(entry.get("purpose")):
            errors.append(f"{prefix}.purpose is required")
        status = entry.get("status")
        if status not in {"present", "missing", "pending"}:
            errors.append(f"{prefix}.status is invalid")
        if status == "missing" and not _text(entry.get("reason")):
            errors.append(f"{prefix}.reason is required for missing evidence")
        if entry.get("historical_claim") is not False:
            errors.append(f"{prefix}.historical_claim must be false")

    for key in ("native_execution", "human_review", "release_signoff"):
        gate = value.get(key)
        if not isinstance(gate, dict) or gate.get("status") not in OPEN_STATUSES:
            errors.append(f"{label}.{key}.status must remain open")
        elif gate.get("status") == "not_performed" and gate.get("evidence") is not None:
            errors.append(f"{label}.{key}.evidence must be null when not_performed")
    exclusions = value.get("claims_excluded")
    required = {"native_execution", "human_review", "release_signoff"}
    if not isinstance(exclusions, list) or not required.issubset(set(exclusions)):
        errors.append(f"{label}.claims_excluded must retain all open gates")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("index", type=Path)
    args = parser.parse_args(argv)
    errors = validate_index(json.loads(args.index.read_text(encoding="utf-8")))
    if errors:
        print("PLANETARY_PACKAGE_EVIDENCE_INDEX_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PLANETARY_PACKAGE_EVIDENCE_INDEX_VALID_OPEN")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
