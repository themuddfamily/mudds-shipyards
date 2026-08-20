#!/usr/bin/env python3
"""Validate v10 root lineage for planetary hazard visual evidence."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

SCHEMA = "planetary_hazard_lineage_root_visual_digest_v10"
OPEN = {"pending", "not_performed"}
KINDS = {"hazard", "landmark", "route"}


def validate_digest(value: Any, label: str = "digest") -> list[str]:
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema") != SCHEMA:
        errors.append(f"{label}.schema must be {SCHEMA}")
    for key in ("world_id", "region_id", "source_revision", "root_id"):
        if not isinstance(value.get(key), str) or not value[key].strip():
            errors.append(f"{label}.{key} is required")
    records = value.get("records")
    if not isinstance(records, list) or not records:
        errors.append(f"{label}.records must contain lineage records")
        records = []
    ids: set[str] = set()
    parent_map: dict[str, str] = {}
    for index, record in enumerate(records):
        prefix = f"{label}.records[{index}]"
        if not isinstance(record, dict):
            errors.append(f"{prefix} must be an object")
            continue
        ident, parent = record.get("id"), record.get("parent_id")
        if not isinstance(ident, str) or not ident.strip() or ident in ids:
            errors.append(f"{prefix}.id must be unique")
        ids.add(ident)
        if record.get("kind") not in KINDS:
            errors.append(f"{prefix}.kind is invalid")
        if not isinstance(parent, str) or not parent.strip():
            errors.append(f"{prefix}.parent_id is required")
        else:
            parent_map[ident] = parent
        if record.get("status") not in OPEN:
            errors.append(f"{prefix}.status must remain open")
    root_id = value.get("root_id")
    if root_id in ids:
        errors.append(f"{label}.root_id must be external to record IDs")
    for ident, parent in parent_map.items():
        if parent != root_id and parent not in ids:
            errors.append(f"{label}.records[{ident}].parent_id must reference root or a record")
        seen: set[str] = set()
        cursor = ident
        while cursor in parent_map and cursor not in seen:
            seen.add(cursor)
            cursor = parent_map[cursor]
        if cursor != root_id:
            errors.append(f"{label}.records[{ident}] lineage must terminate at root_id")
    if value.get("lineage_status") not in OPEN:
        errors.append(f"{label}.lineage_status must remain open")
    for key in ("native_render", "human_signoff"):
        gate = value.get(key)
        if not isinstance(gate, dict) or gate.get("status") not in OPEN:
            errors.append(f"{label}.{key}.status must remain open")
    exclusions = value.get("claims_excluded")
    if not isinstance(exclusions, list) or not {"lineage_approval", "native_render", "human_signoff"}.issubset(set(exclusions)):
        errors.append(f"{label}.claims_excluded must preserve all open gates")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("digest", type=Path)
    args = parser.parse_args(argv)
    errors = validate_digest(json.loads(args.digest.read_text(encoding="utf-8")))
    if errors:
        print("PLANETARY_LINEAGE_ROOT_V10_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PLANETARY_LINEAGE_ROOT_V10_VALID_OPEN")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
