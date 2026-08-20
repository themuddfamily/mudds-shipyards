#!/usr/bin/env python3
"""Validate the metadata contract for authored/baked/scanned ORM materials.

This gate intentionally validates declarations, not image quality or the
presence of artist-produced textures.  ``metadata_only`` is the only status
accepted by the checked-in roadmap fixture until a human-owned bake pipeline
and source meshes are supplied.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

SCHEMA_VERSION = 1
MATERIAL_STATUSES = {"metadata_only", "authored", "baked", "scanned"}
MAP_KINDS = {"authored", "baked", "scanned", "derived", "missing"}
ORM_CHANNELS = {"r": "occlusion", "g": "roughness", "b": "metallic"}


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def validate_contract(value: Any, label: str = "contract") -> list[str]:
    """Return structural and claim-safety errors for one material contract."""
    errors: list[str] = []
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    status = value.get("status")
    if status not in MATERIAL_STATUSES:
        errors.append(f"{label}.status must be one of {sorted(MATERIAL_STATUSES)}")
    if not _text(value.get("source_mesh")):
        errors.append(f"{label}.source_mesh must identify a source mesh")
    if value.get("claim_scope") != "metadata_contract_only":
        errors.append(f"{label}.claim_scope must be metadata_contract_only")
    materials = value.get("materials")
    if not isinstance(materials, list) or not materials:
        errors.append(f"{label}.materials must be a non-empty array")
        return errors
    ids: set[str] = set()
    for index, material in enumerate(materials):
        prefix = f"{label}.materials[{index}]"
        if not isinstance(material, dict):
            errors.append(f"{prefix} must be an object")
            continue
        material_id = material.get("id")
        if not _text(material_id):
            errors.append(f"{prefix}.id must be non-empty")
        elif material_id in ids:
            errors.append(f"{prefix}.id must be unique")
        else:
            ids.add(material_id)
        if not _text(material.get("role")):
            errors.append(f"{prefix}.role must be non-empty")
        maps = material.get("maps")
        if not isinstance(maps, dict):
            errors.append(f"{prefix}.maps must be an object")
            continue
        for map_name in ("albedo", "normal", "roughness", "metallic", "orm"):
            row = maps.get(map_name)
            if not isinstance(row, dict):
                errors.append(f"{prefix}.maps.{map_name} must be an object")
                continue
            kind = row.get("kind")
            if kind not in MAP_KINDS:
                errors.append(f"{prefix}.maps.{map_name}.kind is invalid")
            path = row.get("path")
            if kind == "missing" and path is not None:
                errors.append(f"{prefix}.maps.{map_name}.path must be null when missing")
            if kind != "missing" and not _text(path):
                errors.append(f"{prefix}.maps.{map_name}.path is required for {kind}")
        orm = maps.get("orm")
        if isinstance(orm, dict) and orm.get("packed") is True:
            if orm.get("channels") != ORM_CHANNELS:
                errors.append(f"{prefix}.maps.orm.channels must map R/G/B to occlusion/roughness/metallic")
            if not _text(orm.get("path")):
                errors.append(f"{prefix}.maps.orm.path is required for packed ORM")
    if status != "metadata_only":
        errors.append(f"{label}.status cannot claim artist output before human bake evidence")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("contract", type=Path)
    args = parser.parse_args()
    errors = validate_contract(json.loads(args.contract.read_text(encoding="utf-8")))
    if errors:
        print("ORM_MATERIAL_CONTRACT_INVALID")
        for error in errors:
            print(f"- {error}")
        return 1
    print("ORM_MATERIAL_CONTRACT_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
