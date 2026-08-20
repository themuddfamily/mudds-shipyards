#!/usr/bin/env python3
"""Validate v12 planetary hazard reconciliation visual manifest."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

SCHEMA = "planetary_hazard_reconciliation_manifest_visual_v12"
OPEN = {"pending", "not_performed"}
KINDS = {"hazard", "landmark", "route"}


def validate_manifest(value: Any, label: str = "manifest") -> list[str]:
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema") != SCHEMA:
        errors.append(f"{label}.schema must be {SCHEMA}")
    for key in ("world_id", "region_id", "source_revision", "root_id"):
        if not isinstance(value.get(key), str) or not value[key].strip():
            errors.append(f"{label}.{key} is required")
    leaves = value.get("leaves")
    if not isinstance(leaves, list) or len(leaves) != 3:
        errors.append(f"{label}.leaves must contain exactly three visual leaves")
        leaves = leaves if isinstance(leaves, list) else []
    ids: set[str] = set()
    kinds: set[str] = set()
    for index, leaf in enumerate(leaves):
        prefix = f"{label}.leaves[{index}]"
        if not isinstance(leaf, dict):
            errors.append(f"{prefix} must be an object")
            continue
        ident = leaf.get("id")
        if not isinstance(ident, str) or not ident.strip() or ident in ids:
            errors.append(f"{prefix}.id must be unique")
        ids.add(ident)
        kind = leaf.get("kind")
        if kind not in KINDS:
            errors.append(f"{prefix}.kind is invalid")
        kinds.add(kind)
        if leaf.get("parent_id") != value.get("root_id"):
            errors.append(f"{prefix}.parent_id must equal root_id")
        if not isinstance(leaf.get("evidence_path"), str) or not leaf["evidence_path"].startswith("res://"):
            errors.append(f"{prefix}.evidence_path must be a res:// path")
        if leaf.get("status") not in OPEN:
            errors.append(f"{prefix}.status must remain open")
    if kinds != KINDS:
        errors.append(f"{label}.leaves must cover hazard, landmark, and route exactly")
    if value.get("manifest_status") not in OPEN:
        errors.append(f"{label}.manifest_status must remain open")
    for key in ("native_render", "human_signoff"):
        gate = value.get(key)
        if not isinstance(gate, dict) or gate.get("status") not in OPEN:
            errors.append(f"{label}.{key}.status must remain open")
    exclusions = value.get("claims_excluded")
    if not isinstance(exclusions, list) or not {"manifest_approval", "native_render", "human_signoff"}.issubset(set(exclusions)):
        errors.append(f"{label}.claims_excluded must preserve all open gates")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    args = parser.parse_args(argv)
    errors = validate_manifest(json.loads(args.manifest.read_text(encoding="utf-8")))
    if errors:
        print("PLANETARY_RECONCILIATION_V12_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PLANETARY_RECONCILIATION_V12_VALID_OPEN")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
