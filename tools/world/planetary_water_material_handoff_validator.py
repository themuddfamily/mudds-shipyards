#!/usr/bin/env python3
"""Validate detached planetary water and surface-material handoff evidence.

The manifest names one authored Aurora water feature, its ordered material
layers, shoreline hazards, recovery routes, and surface-audio routes.  It does
not bind a renderer resource, simulate water, resolve hazards, or claim native
execution.
"""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 1
EVIDENCE_SCOPE = "planetary_water_surface_material_handoff"
EVIDENCE_MODE = "detached_authored_material_fixture"
REQUIRED_WORLD_ID = "aurora_temperate_world"
REQUIRED_REGION_ID = "aurora_foundation_landing"
REQUIRED_LAYER_KINDS = ("water", "shoreline", "substrate")
REQUIRED_WATER_KINDS = {"coastal_inlet", "lake", "river", "ocean_shelf"}
REQUIRED_HAZARD_KINDS = {"undertow", "slippery_shore", "unstable_bank", "tide_cut"}


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _vector(value: Any) -> bool:
    return isinstance(value, list) and len(value) == 3 and all(
        isinstance(item, (int, float)) and not isinstance(item, bool) and math.isfinite(item)
        for item in value
    )


def _unique(values: list[Any], label: str, errors: list[str]) -> None:
    if len(set(values)) != len(values):
        errors.append(f"{label} must not contain duplicate IDs")


def validate_handoff(value: Any, label: str = "handoff") -> list[str]:
    """Return blocking errors for one detached water/material handoff."""

    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    if value.get("evidence_scope") != EVIDENCE_SCOPE:
        errors.append(f"{label}.evidence_scope must be {EVIDENCE_SCOPE}")
    if value.get("evidence_mode") != EVIDENCE_MODE:
        errors.append(f"{label}.evidence_mode must be {EVIDENCE_MODE}")
    for key in ("renderer_binding", "water_simulation", "hazard_resolution", "audio_playback", "native_claims", "runtime_authority"):
        if value.get(key) is not False:
            errors.append(f"{label}.{key} must be false")

    identity = value.get("identity")
    if not isinstance(identity, dict):
        errors.append(f"{label}.identity must be an object")
    else:
        if identity.get("world_id") != REQUIRED_WORLD_ID:
            errors.append(f"{label}.identity.world_id must be {REQUIRED_WORLD_ID}")
        if identity.get("landing_region_id") != REQUIRED_REGION_ID:
            errors.append(f"{label}.identity.landing_region_id must be {REQUIRED_REGION_ID}")
        for key in ("surface_feature_id", "display_name"):
            if not _text(identity.get(key)):
                errors.append(f"{label}.identity.{key} is required")

    water = value.get("water")
    if not isinstance(water, dict):
        errors.append(f"{label}.water must be an object")
    else:
        if water.get("water_appropriate") is not True:
            errors.append(f"{label}.water.water_appropriate must be true")
        if not _text(water.get("body_id")):
            errors.append(f"{label}.water.body_id is required")
        if water.get("body_kind") not in REQUIRED_WATER_KINDS:
            errors.append(f"{label}.water.body_kind is not an authored water kind")

    materials = value.get("materials")
    if not isinstance(materials, list) or len(materials) != 3:
        errors.append(f"{label}.materials must contain exactly three ordered layers")
        materials = []
    material_ids: list[str] = []
    audio_routes: list[str] = []
    for index, material in enumerate(materials):
        prefix = f"{label}.materials[{index}]"
        if not isinstance(material, dict):
            errors.append(f"{prefix} must be an object")
            continue
        material_id = material.get("id")
        if not _text(material_id):
            errors.append(f"{prefix}.id is required")
        material_ids.append(material_id)
        if material.get("kind") != REQUIRED_LAYER_KINDS[index]:
            errors.append(f"{prefix}.kind must be {REQUIRED_LAYER_KINDS[index]}")
        route_id = material.get("audio_route_id")
        if not _text(route_id) or not route_id.startswith("planetary_"):
            errors.append(f"{prefix}.audio_route_id must be an opaque planetary_ route")
        audio_routes.append(route_id)
    _unique(material_ids, f"{label}.materials IDs", errors)
    _unique(audio_routes, f"{label}.materials audio routes", errors)
    material_handoffs = value.get("material_handoffs")
    if not isinstance(material_handoffs, dict):
        errors.append(f"{label}.material_handoffs must be an object")
    else:
        for key in REQUIRED_LAYER_KINDS:
            if not _text(material_handoffs.get(key)):
                errors.append(f"{label}.material_handoffs.{key} is required")

    hazards = value.get("shoreline_hazards")
    if not isinstance(hazards, list) or len(hazards) < 2:
        errors.append(f"{label}.shoreline_hazards must contain at least two authored hazards")
        hazards = []
    hazard_ids: list[str] = []
    for index, hazard in enumerate(hazards):
        prefix = f"{label}.shoreline_hazards[{index}]"
        if not isinstance(hazard, dict):
            errors.append(f"{prefix} must be an object")
            continue
        hazard_id = hazard.get("id")
        if not _text(hazard_id):
            errors.append(f"{prefix}.id is required")
        hazard_ids.append(hazard_id)
        if hazard.get("kind") not in REQUIRED_HAZARD_KINDS:
            errors.append(f"{prefix}.kind is not an authored shoreline hazard kind")
        if not _vector(hazard.get("body_local_m")):
            errors.append(f"{prefix}.body_local_m must be three finite metres")
        for key in ("route_id", "recovery_id"):
            if not _text(hazard.get(key)):
                errors.append(f"{prefix}.{key} is required")
    _unique(hazard_ids, f"{label}.shoreline_hazards IDs", errors)

    audio = value.get("audio")
    if not isinstance(audio, dict):
        errors.append(f"{label}.audio must be an object")
    else:
        if audio.get("authority_id") != "planetary_surface_audio_policy":
            errors.append(f"{label}.audio.authority_id must be planetary_surface_audio_policy")
        if audio.get("routes_are_opaque_hints") is not True:
            errors.append(f"{label}.audio.routes_are_opaque_hints must be true")
        if audio.get("profile_resolution_requested") is not False or audio.get("playback_requested") is not False:
            errors.append(f"{label}.audio must not request resolution or playback")
        routes = audio.get("route_ids")
        if not isinstance(routes, list) or len(routes) != 3:
            errors.append(f"{label}.audio.route_ids must contain three routes")

    evidence = value.get("evidence")
    if not isinstance(evidence, dict):
        errors.append(f"{label}.evidence must be an object")
    else:
        if evidence.get("status") != "modern_interpretation":
            errors.append(f"{label}.evidence.status must be modern_interpretation")
        if evidence.get("historical_claim") is not False or evidence.get("procedural_generation") is not False:
            errors.append(f"{label}.evidence must make no historical or procedural claim")
        references = evidence.get("references")
        if not isinstance(references, list) or not references or not all(_text(item) and item.startswith("res://") for item in references):
            errors.append(f"{label}.evidence.references must contain res:// paths")

    authority = value.get("authority")
    if not isinstance(authority, dict):
        errors.append(f"{label}.authority must be an object")
    else:
        for key in ("renderer", "material_binding", "water_simulation", "terrain_generation", "collision_generation", "physics", "hazard_resolution", "audio_route_resolution", "audio_playback", "streaming", "save", "network"):
            if authority.get(key) is not False:
                errors.append(f"{label}.authority.{key} must be false")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("handoff", type=Path)
    args = parser.parse_args(argv)
    try:
        report = json.loads(args.handoff.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        print(f"PLANETARY_WATER_MATERIAL_INVALID: {exc}")
        return 1
    errors = validate_handoff(report)
    if errors:
        print("PLANETARY_WATER_MATERIAL_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PLANETARY_WATER_MATERIAL_VALID: detached authored handoff only")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
