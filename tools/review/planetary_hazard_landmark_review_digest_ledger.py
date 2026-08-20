#!/usr/bin/env python3
"""Validate an aggregate visual-review digest ledger for hazard landmarks."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

SCHEMA = "planetary_hazard_landmark_review_digest_v1"
OPEN = {"pending", "not_performed"}
HEX64 = re.compile(r"^[0-9a-fA-F]{64}$")


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def validate_ledger(value: Any, label: str = "ledger") -> list[str]:
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema") != SCHEMA:
        errors.append(f"{label}.schema must be {SCHEMA}")
    for key in ("world_id", "region_id", "source_revision"):
        if not _text(value.get(key)):
            errors.append(f"{label}.{key} is required")
    records = value.get("records")
    if not isinstance(records, list) or not records:
        errors.append(f"{label}.records must contain visual records")
        records = []
    ids: set[str] = set()
    for index, record in enumerate(records):
        prefix = f"{label}.records[{index}]"
        if not isinstance(record, dict):
            errors.append(f"{prefix} must be an object")
            continue
        ident = record.get("id")
        if not _text(ident) or ident in ids:
            errors.append(f"{prefix}.id must be unique")
        ids.add(ident)
        if record.get("kind") not in {"hazard", "landmark", "route"}:
            errors.append(f"{prefix}.kind is invalid")
        if not _text(record.get("capture_path")) or not record["capture_path"].startswith("res://"):
            errors.append(f"{prefix}.capture_path must be a res:// path")
        if not isinstance(record.get("sha256"), str) or not HEX64.fullmatch(record["sha256"]):
            errors.append(f"{prefix}.sha256 must be a 64-character digest")
        if record.get("review_status") not in OPEN:
            errors.append(f"{prefix}.review_status must remain open")
        if not _text(record.get("question")):
            errors.append(f"{prefix}.question is required")
    aggregate = value.get("aggregate_digest")
    if not isinstance(aggregate, dict) or not isinstance(aggregate.get("sha256"), str) or not HEX64.fullmatch(aggregate["sha256"]):
        errors.append(f"{label}.aggregate_digest.sha256 must be a 64-character digest")
    elif aggregate.get("status") not in OPEN:
        errors.append(f"{label}.aggregate_digest.status must remain open")
    for key in ("native_render", "human_review"):
        gate = value.get(key)
        if not isinstance(gate, dict) or gate.get("status") not in OPEN:
            errors.append(f"{label}.{key}.status must remain open")
    exclusions = value.get("claims_excluded")
    if not isinstance(exclusions, list) or not {"digest_verification", "native_render", "human_review"}.issubset(set(exclusions)):
        errors.append(f"{label}.claims_excluded must preserve all open gates")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("ledger", type=Path)
    args = parser.parse_args(argv)
    errors = validate_ledger(json.loads(args.ledger.read_text(encoding="utf-8")))
    if errors:
        print("PLANETARY_HAZARD_REVIEW_DIGEST_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PLANETARY_HAZARD_REVIEW_DIGEST_VALID_OPEN")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
