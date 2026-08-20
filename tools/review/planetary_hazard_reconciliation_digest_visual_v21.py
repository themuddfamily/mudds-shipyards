#!/usr/bin/env python3
"""Validate v21 reconciliation digest metadata for planetary evidence."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

SCHEMA = "planetary_hazard_reconciliation_digest_visual_v21"
OPEN = {"pending", "not_performed"}
KINDS = {"hazard", "landmark", "route"}
HEX64 = re.compile(r"^[0-9a-fA-F]{64}$")


def validate_digest(value: Any, label: str = "digest") -> list[str]:
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema") != SCHEMA:
        errors.append(f"{label}.schema must be {SCHEMA}")
    for key in ("world_id", "region_id", "manifest_id", "source_revision"):
        if not isinstance(value.get(key), str) or not value[key].strip():
            errors.append(f"{label}.{key} is required")
    records = value.get("records")
    if not isinstance(records, list) or len(records) != 3:
        errors.append(f"{label}.records must contain exactly three records")
        records = records if isinstance(records, list) else []
    kinds: set[str] = set()
    ids: set[str] = set()
    for index, record in enumerate(records):
        prefix = f"{label}.records[{index}]"
        if not isinstance(record, dict):
            errors.append(f"{prefix} must be an object")
            continue
        ident = record.get("id")
        if not isinstance(ident, str) or not ident.strip() or ident in ids:
            errors.append(f"{prefix}.id must be unique")
        ids.add(ident)
        kind = record.get("kind")
        if kind not in KINDS:
            errors.append(f"{prefix}.kind is invalid")
        kinds.add(kind)
        if record.get("manifest_id") != value.get("manifest_id"):
            errors.append(f"{prefix}.manifest_id must match manifest")
        if not isinstance(record.get("digest_path"), str) or not record["digest_path"].startswith("res://"):
            errors.append(f"{prefix}.digest_path must be a res:// path")
        if not isinstance(record.get("sha256"), str) or not HEX64.fullmatch(record["sha256"]):
            errors.append(f"{prefix}.sha256 must be a 64-character digest")
        if record.get("reconciled") is not False:
            errors.append(f"{prefix}.reconciled must remain false")
        if record.get("status") not in OPEN:
            errors.append(f"{prefix}.status must remain open")
    if kinds != KINDS:
        errors.append(f"{label}.records must cover hazard, landmark, and route")
    aggregate = value.get("aggregate_digest")
    if not isinstance(aggregate, dict) or not isinstance(aggregate.get("sha256"), str) or not HEX64.fullmatch(aggregate["sha256"]):
        errors.append(f"{label}.aggregate_digest.sha256 must be a 64-character digest")
    elif aggregate.get("status") not in OPEN:
        errors.append(f"{label}.aggregate_digest.status must remain open")
    for key in ("native_render", "human_signoff"):
        gate = value.get(key)
        if not isinstance(gate, dict) or gate.get("status") not in OPEN:
            errors.append(f"{label}.{key}.status must remain open")
    exclusions = value.get("claims_excluded")
    if not isinstance(exclusions, list) or not {"reconciliation_approval", "native_render", "human_signoff"}.issubset(set(exclusions)):
        errors.append(f"{label}.claims_excluded must preserve all open gates")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("digest", type=Path)
    args = parser.parse_args(argv)
    errors = validate_digest(json.loads(args.digest.read_text(encoding="utf-8")))
    if errors:
        print("PLANETARY_RECONCILIATION_DIGEST_V21_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PLANETARY_RECONCILIATION_DIGEST_V21_VALID_OPEN")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
