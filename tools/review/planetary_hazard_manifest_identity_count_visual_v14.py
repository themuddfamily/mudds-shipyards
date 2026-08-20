#!/usr/bin/env python3
"""Validate v14 identity/count metadata for planetary visual manifests."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

SCHEMA = "planetary_hazard_manifest_identity_count_visual_v14"
OPEN = {"pending", "not_performed"}
KINDS = ("hazard", "landmark", "route")


def validate_manifest(value: Any, label: str = "manifest") -> list[str]:
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema") != SCHEMA:
        errors.append(f"{label}.schema must be {SCHEMA}")
    for key in ("world_id", "region_id", "manifest_id", "source_revision"):
        if not isinstance(value.get(key), str) or not value[key].strip():
            errors.append(f"{label}.{key} is required")
    counts = value.get("counts")
    if not isinstance(counts, dict):
        errors.append(f"{label}.counts must be an object")
    else:
        for kind in KINDS:
            if not isinstance(counts.get(kind), int) or isinstance(counts.get(kind), bool) or counts[kind] < 1:
                errors.append(f"{label}.counts.{kind} must be positive")
        total = counts.get("total")
        if not isinstance(total, int) or isinstance(total, bool) or total < 3:
            errors.append(f"{label}.counts.total must be at least three")
        elif all(isinstance(counts.get(kind), int) and not isinstance(counts.get(kind), bool) for kind in KINDS) and total != sum(counts[kind] for kind in KINDS):
            errors.append(f"{label}.counts.total must equal category sum")
    records = value.get("records")
    if not isinstance(records, list) or len(records) != 3:
        errors.append(f"{label}.records must contain exactly three records")
        records = records if isinstance(records, list) else []
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
        if record.get("kind") not in KINDS:
            errors.append(f"{prefix}.kind is invalid")
        if record.get("manifest_id") != value.get("manifest_id"):
            errors.append(f"{prefix}.manifest_id must match manifest")
        if record.get("status") not in OPEN:
            errors.append(f"{prefix}.status must remain open")
    if {record.get("kind") for record in records if isinstance(record, dict)} != set(KINDS):
        errors.append(f"{label}.records must cover hazard, landmark, and route")
    if value.get("identity_count_status") not in OPEN:
        errors.append(f"{label}.identity_count_status must remain open")
    for key in ("native_render", "human_signoff"):
        gate = value.get(key)
        if not isinstance(gate, dict) or gate.get("status") not in OPEN:
            errors.append(f"{label}.{key}.status must remain open")
    exclusions = value.get("claims_excluded")
    if not isinstance(exclusions, list) or not {"identity_count_approval", "native_render", "human_signoff"}.issubset(set(exclusions)):
        errors.append(f"{label}.claims_excluded must preserve all open gates")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    args = parser.parse_args(argv)
    errors = validate_manifest(json.loads(args.manifest.read_text(encoding="utf-8")))
    if errors:
        print("PLANETARY_IDENTITY_COUNT_V14_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PLANETARY_IDENTITY_COUNT_V14_VALID_OPEN")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
