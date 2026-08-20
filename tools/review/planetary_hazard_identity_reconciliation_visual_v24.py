#!/usr/bin/env python3
"""Validate v24 identity reconciliation for planetary hazard visuals."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

SCHEMA = "planetary_hazard_identity_reconciliation_visual_v24"
OPEN = {"pending", "not_performed"}
KINDS = {"hazard", "landmark", "route"}


def validate_manifest(value: Any, label: str = "manifest") -> list[str]:
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema") != SCHEMA:
        errors.append(f"{label}.schema must be {SCHEMA}")
    for key in ("world_id", "region_id", "manifest_id", "source_revision"):
        if not isinstance(value.get(key), str) or not value[key].strip():
            errors.append(f"{label}.{key} is required")
    identities = value.get("identities")
    if not isinstance(identities, list) or len(identities) != 3:
        errors.append(f"{label}.identities must contain exactly three identities")
        identities = identities if isinstance(identities, list) else []
    kinds: set[str] = set()
    ids: set[str] = set()
    for index, identity in enumerate(identities):
        prefix = f"{label}.identities[{index}]"
        if not isinstance(identity, dict):
            errors.append(f"{prefix} must be an object")
            continue
        ident = identity.get("id")
        if not isinstance(ident, str) or not ident.strip() or ident in ids:
            errors.append(f"{prefix}.id must be unique")
        ids.add(ident)
        kind = identity.get("kind")
        if kind not in KINDS:
            errors.append(f"{prefix}.kind is invalid")
        kinds.add(kind)
        if identity.get("world_id") != value.get("world_id") or identity.get("region_id") != value.get("region_id"):
            errors.append(f"{prefix}.world_id and region_id must match manifest")
        if identity.get("manifest_id") != value.get("manifest_id"):
            errors.append(f"{prefix}.manifest_id must match manifest")
        if identity.get("reconciled") is not False:
            errors.append(f"{prefix}.reconciled must remain false")
        if identity.get("status") not in OPEN:
            errors.append(f"{prefix}.status must remain open")
    if kinds != KINDS:
        errors.append(f"{label}.identities must cover hazard, landmark, and route")
    if value.get("identity_status") not in OPEN:
        errors.append(f"{label}.identity_status must remain open")
    for key in ("native_render", "human_signoff"):
        gate = value.get(key)
        if not isinstance(gate, dict) or gate.get("status") not in OPEN:
            errors.append(f"{label}.{key}.status must remain open")
    exclusions = value.get("claims_excluded")
    if not isinstance(exclusions, list) or not {"identity_approval", "native_render", "human_signoff"}.issubset(set(exclusions)):
        errors.append(f"{label}.claims_excluded must preserve all open gates")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    args = parser.parse_args(argv)
    errors = validate_manifest(json.loads(args.manifest.read_text(encoding="utf-8")))
    if errors:
        print("PLANETARY_IDENTITY_RECONCILIATION_V24_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PLANETARY_IDENTITY_RECONCILIATION_V24_VALID_OPEN")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
