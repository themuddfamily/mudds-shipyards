#!/usr/bin/env python3
"""Validate v11 root/leaf reconciliation for planetary visual evidence."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

SCHEMA = "planetary_hazard_root_leaf_reconciliation_digest_v11"
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
    leaves = value.get("leaves")
    if not isinstance(leaves, list) or not leaves:
        errors.append(f"{label}.leaves must contain reconciliation leaves")
        leaves = []
    ids: set[str] = set()
    kinds: set[str] = set()
    for index, leaf in enumerate(leaves):
        prefix = f"{label}.leaves[{index}]"
        if not isinstance(leaf, dict):
            errors.append(f"{prefix} must be an object")
            continue
        ident, parent = leaf.get("id"), leaf.get("parent_id")
        if not isinstance(ident, str) or not ident.strip() or ident in ids:
            errors.append(f"{prefix}.id must be unique")
        ids.add(ident)
        kind = leaf.get("kind")
        if kind not in KINDS:
            errors.append(f"{prefix}.kind is invalid")
        kinds.add(kind)
        if parent != value.get("root_id") and parent not in ids:
            # Parent ordering is intentionally strict: reconciliation records
            # must list a parent before any child leaf.
            errors.append(f"{prefix}.parent_id must reference root or an earlier leaf")
        if leaf.get("reconciled") is not False:
            errors.append(f"{prefix}.reconciled must remain false until review")
        if leaf.get("status") not in OPEN:
            errors.append(f"{prefix}.status must remain open")
    if not KINDS.issubset(kinds):
        errors.append(f"{label}.leaves must cover hazard, landmark, and route")
    counts = value.get("leaf_counts")
    if not isinstance(counts, dict):
        errors.append(f"{label}.leaf_counts must be an object")
    else:
        for kind in KINDS:
            if counts.get(kind) != sum(1 for leaf in leaves if isinstance(leaf, dict) and leaf.get("kind") == kind):
                errors.append(f"{label}.leaf_counts.{kind} must match leaves")
    if value.get("reconciliation_status") not in OPEN:
        errors.append(f"{label}.reconciliation_status must remain open")
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
        print("PLANETARY_ROOT_LEAF_RECONCILIATION_V11_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PLANETARY_ROOT_LEAF_RECONCILIATION_V11_VALID_OPEN")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
