#!/usr/bin/env python3
"""Validate the boundary for deliberately authored planetary wildlife.

This record keeps wildlife optional and authored.  It does not spawn actors,
simulate AI, resolve damage, or claim a gameplay/native run.
"""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
from typing import Any

SCHEMA_VERSION = 1
MAX_SPECIES = 16
MAX_ENCOUNTERS = 64
KINDS = {"grazer", "scavenger", "burrower", "flying_predator"}


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _position(value: Any) -> bool:
    return isinstance(value, list) and len(value) == 3 and all(isinstance(item, (int, float)) and not isinstance(item, bool) and math.isfinite(item) for item in value)


def validate_boundary(value: Any, label: str = "boundary") -> list[str]:
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    for key in ("world_id", "region_id"):
        if not _text(value.get(key)):
            errors.append(f"{label}.{key} is required")
    species = value.get("species")
    if not isinstance(species, list) or len(species) > MAX_SPECIES:
        errors.append(f"{label}.species must contain at most {MAX_SPECIES} entries")
        species = []
    species_ids: set[str] = set()
    for index, item in enumerate(species):
        prefix = f"{label}.species[{index}]"
        if not isinstance(item, dict):
            errors.append(f"{prefix} must be an object")
            continue
        ident = item.get("id")
        if not _text(ident) or ident in species_ids:
            errors.append(f"{prefix}.id must be unique non-empty text")
        species_ids.add(ident)
        if item.get("kind") not in KINDS:
            errors.append(f"{prefix}.kind is invalid")
        if item.get("authorship") != "deliberately_authored":
            errors.append(f"{prefix}.authorship must be deliberately_authored")
        if not _text(item.get("asset_path")) or not item["asset_path"].startswith("res://"):
            errors.append(f"{prefix}.asset_path must be a res:// path")
        if item.get("procedural_population") is not False:
            errors.append(f"{prefix}.procedural_population must be false")

    encounters = value.get("encounters")
    if not isinstance(encounters, list) or len(encounters) > MAX_ENCOUNTERS:
        errors.append(f"{label}.encounters must contain at most {MAX_ENCOUNTERS} entries")
        encounters = []
    encounter_ids: set[str] = set()
    for index, item in enumerate(encounters):
        prefix = f"{label}.encounters[{index}]"
        if not isinstance(item, dict):
            errors.append(f"{prefix} must be an object")
            continue
        ident = item.get("id")
        if not _text(ident) or ident in encounter_ids:
            errors.append(f"{prefix}.id must be unique non-empty text")
        encounter_ids.add(ident)
        if item.get("species_id") not in species_ids:
            errors.append(f"{prefix}.species_id must reference authored species")
        if not _position(item.get("body_local_m")):
            errors.append(f"{prefix}.body_local_m must be three finite metres")
        if not _text(item.get("route_id")) or not _text(item.get("recovery_id")):
            errors.append(f"{prefix} requires route_id and recovery_id handoffs")
        if item.get("runtime_resolution") != "external_wildlife_authority":
            errors.append(f"{prefix}.runtime_resolution must remain external")

    if not isinstance(value.get("wildlife_enabled"), bool):
        errors.append(f"{label}.wildlife_enabled must be explicit boolean")
    if value.get("wildlife_enabled") and not species:
        errors.append(f"{label}.wildlife_enabled requires authored species")
    native = value.get("native_run")
    if not isinstance(native, dict) or native.get("status") != "NOT_RUN" or native.get("evidence") is not None:
        errors.append(f"{label}.native_run must remain NOT_RUN without evidence")
    exclusions = value.get("authority_exclusions")
    required = {"actor_spawn", "ai_simulation", "damage_resolution", "native_run"}
    if not isinstance(exclusions, list) or not required.issubset(set(exclusions)):
        errors.append(f"{label}.authority_exclusions must retain runtime and native exclusions")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("boundary", type=Path)
    args = parser.parse_args(argv)
    errors = validate_boundary(json.loads(args.boundary.read_text(encoding="utf-8")))
    if errors:
        print("PLANETARY_WILDLIFE_BOUNDARY_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PLANETARY_WILDLIFE_BOUNDARY_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
