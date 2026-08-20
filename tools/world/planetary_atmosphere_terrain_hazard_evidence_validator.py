#!/usr/bin/env python3
"""Validate authored planetary atmosphere, terrain, and hazard evidence.

This is a structural evidence gate only.  It does not render atmosphere,
generate terrain, simulate hazards, or perform an orbit/surface run.
"""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
from typing import Any

SCHEMA_VERSION = 1
HAZARD_KINDS = {"unstable_terrain", "exposed_reactor", "dust_surge", "collapsed_structure"}
MAX_HAZARDS = 64


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _finite(value: Any) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value)


def _vector(value: Any) -> bool:
    return isinstance(value, list) and len(value) == 3 and all(_finite(item) for item in value)


def validate_evidence(value: Any, label: str = "evidence") -> list[str]:
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    for key in ("world_id", "region_id", "radius_datum"):
        if not _text(value.get(key)):
            errors.append(f"{label}.{key} is required")

    atmosphere = value.get("atmosphere")
    if not isinstance(atmosphere, dict):
        errors.append(f"{label}.atmosphere must be an object")
    else:
        for key in ("body_radius_m", "outer_radius_m", "cloud_base_m", "cloud_top_m"):
            if not _finite(atmosphere.get(key)) or atmosphere.get(key) < 0:
                errors.append(f"{label}.atmosphere.{key} must be a non-negative finite metre value")
        if all(_finite(atmosphere.get(key)) for key in ("body_radius_m", "outer_radius_m")) and atmosphere["outer_radius_m"] <= atmosphere["body_radius_m"]:
            errors.append(f"{label}.atmosphere.outer_radius_m must exceed body radius")
        if all(_finite(atmosphere.get(key)) for key in ("cloud_base_m", "cloud_top_m")) and atmosphere["cloud_base_m"] > atmosphere["cloud_top_m"]:
            errors.append(f"{label}.atmosphere cloud bounds must be ordered")
        if atmosphere.get("render_status") not in {"authored", "pending"}:
            errors.append(f"{label}.atmosphere.render_status must remain authored or pending")

    terrain = value.get("terrain")
    if not isinstance(terrain, dict):
        errors.append(f"{label}.terrain must be an object")
    else:
        for key in ("minimum_radius_m", "maximum_radius_m", "collision_radius_m"):
            if not _finite(terrain.get(key)):
                errors.append(f"{label}.terrain.{key} must be finite")
        if all(_finite(terrain.get(key)) for key in ("minimum_radius_m", "maximum_radius_m")) and terrain["minimum_radius_m"] > terrain["maximum_radius_m"]:
            errors.append(f"{label}.terrain radius bounds must be ordered")
        if all(_finite(terrain.get(key)) for key in ("collision_radius_m", "minimum_radius_m", "maximum_radius_m")) and not terrain["minimum_radius_m"] <= terrain["collision_radius_m"] <= terrain["maximum_radius_m"]:
            errors.append(f"{label}.terrain.collision_radius_m must lie within terrain bounds")
        if terrain.get("lod_status") not in {"authored", "pending"}:
            errors.append(f"{label}.terrain.lod_status must remain authored or pending")

    hazards = value.get("hazards")
    if not isinstance(hazards, list) or len(hazards) > MAX_HAZARDS:
        errors.append(f"{label}.hazards must contain at most {MAX_HAZARDS} entries")
        hazards = []
    seen: set[str] = set()
    terrain_bounds = terrain if isinstance(terrain, dict) else {}
    for index, hazard in enumerate(hazards):
        prefix = f"{label}.hazards[{index}]"
        if not isinstance(hazard, dict):
            errors.append(f"{prefix} must be an object")
            continue
        hazard_id = hazard.get("id")
        if not _text(hazard_id) or hazard_id in seen:
            errors.append(f"{prefix}.id must be unique non-empty text")
        seen.add(hazard_id)
        if hazard.get("kind") not in HAZARD_KINDS:
            errors.append(f"{prefix}.kind is not an authored hazard kind")
        if not _vector(hazard.get("body_local_m")):
            errors.append(f"{prefix}.body_local_m must be three finite metres")
        elif _finite(terrain_bounds.get("minimum_radius_m")) and _finite(terrain_bounds.get("maximum_radius_m")):
            radius = math.sqrt(sum(float(item) ** 2 for item in hazard["body_local_m"]))
            if not terrain_bounds["minimum_radius_m"] <= radius <= terrain_bounds["maximum_radius_m"]:
                errors.append(f"{prefix}.body_local_m lies outside terrain radius bounds")
        if not _text(hazard.get("recovery_id")) or not _text(hazard.get("route_id")):
            errors.append(f"{prefix} requires recovery_id and route_id handoffs")
        if hazard.get("resolution_authority") != "external_hazard_authority":
            errors.append(f"{prefix}.resolution_authority must remain external")

    native = value.get("native_run")
    if not isinstance(native, dict) or native.get("status") != "NOT_RUN" or native.get("evidence") is not None:
        errors.append(f"{label}.native_run must be explicitly NOT_RUN without evidence")
    exclusions = value.get("authority_exclusions")
    required_exclusions = {"atmosphere_rendering", "terrain_generation", "hazard_simulation", "native_run"}
    if not isinstance(exclusions, list) or not required_exclusions.issubset(set(exclusions)):
        errors.append(f"{label}.authority_exclusions must preserve runtime and native gates")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("evidence", type=Path)
    args = parser.parse_args(argv)
    errors = validate_evidence(json.loads(args.evidence.read_text(encoding="utf-8")))
    if errors:
        print("PLANETARY_ATMOSPHERE_TERRAIN_HAZARD_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PLANETARY_ATMOSPHERE_TERRAIN_HAZARD_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
