#!/usr/bin/env python3
"""Validate the bounded station structural-material family extension.

This is a declaration gate for the still-procedural beam, frame and trim
extension.  It deliberately does not imply that an artist-authored normal,
roughness or ORM bake exists.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

SCHEMA_VERSION = 1
REQUIRED_TARGETS = {
    "wider_lattice",
    "catwalk",
    "control_room",
    "aft_structural_beams",
    "habitat_structural_frames",
    "freight_structural_trim",
}
REQUIRED_ROLES = {"beam", "frame", "trim"}


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def validate_contract(value: Any, label: str = "contract") -> list[str]:
    """Return errors without making visual or artist-output claims."""
    errors: list[str] = []
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    if value.get("status") != "metadata_only":
        errors.append(f"{label}.status must be metadata_only")
    if value.get("claim_scope") != "structural_family_metadata_only":
        errors.append(
            f"{label}.claim_scope must be structural_family_metadata_only"
        )
    if value.get("ship_atlas_policy") != "forbidden":
        errors.append(f"{label}.ship_atlas_policy must be forbidden")
    mapping = value.get("mapping")
    if not isinstance(mapping, dict):
        errors.append(f"{label}.mapping must be an object")
    else:
        if mapping.get("projection") != "world_triplanar":
            errors.append(f"{label}.mapping.projection must be world_triplanar")
        if mapping.get("coordinate_space") != "world_metric":
            errors.append(f"{label}.mapping.coordinate_space must be world_metric")
        scales = mapping.get("metric_scales")
        if not isinstance(scales, list) or not scales or any(
            not isinstance(scale, (int, float)) or scale <= 0 for scale in scales
        ):
            errors.append(f"{label}.mapping.metric_scales must be positive numbers")

    targets = value.get("targets")
    if not isinstance(targets, list) or not targets:
        errors.append(f"{label}.targets must be a non-empty array")
        targets = []
    seen: set[str] = set()
    target_ids: set[str] = set()
    roles: set[str] = set()
    for index, target in enumerate(targets):
        prefix = f"{label}.targets[{index}]"
        if not isinstance(target, dict):
            errors.append(f"{prefix} must be an object")
            continue
        target_id = target.get("id")
        if not _text(target_id):
            errors.append(f"{prefix}.id must be non-empty")
        elif target_id in seen:
            errors.append(f"{prefix}.id must be unique")
        else:
            seen.add(target_id)
            target_ids.add(target_id)
        role = target.get("role")
        if role not in REQUIRED_ROLES:
            errors.append(f"{prefix}.role must be one of {sorted(REQUIRED_ROLES)}")
        else:
            roles.add(role)
        if target.get("material_family") != "station_symmetric_panel":
            errors.append(f"{prefix}.material_family must be station_symmetric_panel")
        if target.get("ship_atlas") is not None:
            errors.append(f"{prefix}.ship_atlas must be null")
        if target.get("mapping") != "inherits_world_metric_family":
            errors.append(
                f"{prefix}.mapping must be inherits_world_metric_family"
            )
    missing_targets = REQUIRED_TARGETS - target_ids
    if missing_targets:
        errors.append(f"{label}.targets missing required targets: {sorted(missing_targets)}")
    missing_roles = REQUIRED_ROLES - roles
    if missing_roles:
        errors.append(f"{label}.targets missing required roles: {sorted(missing_roles)}")

    limits = value.get("artist_asset_limitations")
    if not isinstance(limits, dict):
        errors.append(f"{label}.artist_asset_limitations must be an object")
    else:
        for key in ("authored_sets_present", "baked_sets_present", "scanned_sets_present"):
            if limits.get(key) is not False:
                errors.append(f"{label}.artist_asset_limitations.{key} must be false")
        if not _text(limits.get("reason")):
            errors.append(f"{label}.artist_asset_limitations.reason must be explicit")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("contract", type=Path)
    args = parser.parse_args()
    errors = validate_contract(json.loads(args.contract.read_text(encoding="utf-8")))
    if errors:
        print("STATION_STRUCTURAL_MATERIAL_FAMILY_INVALID")
        for error in errors:
            print(f"- {error}")
        return 1
    print("STATION_STRUCTURAL_MATERIAL_FAMILY_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
