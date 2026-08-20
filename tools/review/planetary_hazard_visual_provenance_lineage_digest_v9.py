#!/usr/bin/env python3
"""Validate v9 provenance lineage for planetary visual evidence."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

SCHEMA = "planetary_hazard_visual_provenance_lineage_digest_v9"
OPEN = {"pending", "not_performed"}
HEX64 = re.compile(r"^[0-9a-fA-F]{64}$")
KINDS = {"hazard", "landmark", "route"}


def validate_digest(value: Any, label: str = "digest") -> list[str]:
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema") != SCHEMA:
        errors.append(f"{label}.schema must be {SCHEMA}")
    for key in ("world_id", "region_id", "source_revision"):
        if not isinstance(value.get(key), str) or not value[key].strip():
            errors.append(f"{label}.{key} is required")
    records = value.get("records")
    if not isinstance(records, list) or not records:
        errors.append(f"{label}.records must contain lineage records")
        records = []
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
        if not isinstance(record.get("parent_id"), str) or not record["parent_id"].strip():
            errors.append(f"{prefix}.parent_id is required")
        if not isinstance(record.get("source_path"), str) or not record["source_path"].startswith("res://"):
            errors.append(f"{prefix}.source_path must be a res:// path")
        if not isinstance(record.get("sha256"), str) or not HEX64.fullmatch(record["sha256"]):
            errors.append(f"{prefix}.sha256 must be a 64-character digest")
        if record.get("status") not in OPEN:
            errors.append(f"{prefix}.status must remain open")
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
        print("PLANETARY_PROVENANCE_LINEAGE_V9_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PLANETARY_PROVENANCE_LINEAGE_V9_VALID_OPEN")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
