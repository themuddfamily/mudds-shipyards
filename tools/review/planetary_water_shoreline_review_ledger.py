#!/usr/bin/env python3
"""Validate planetary water/shoreline hazard visual review evidence."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

SCHEMA = "planetary_water_shoreline_review_v1"
OPEN = {"pending", "not_performed"}
HAZARD_KINDS = {"unstable_shore", "deep_water", "submerged_debris", "tidal_surge"}


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def validate_ledger(value: Any, label: str = "ledger") -> list[str]:
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema") != SCHEMA:
        errors.append(f"{label}.schema must be {SCHEMA}")
    for key in ("world_id", "region_id", "source_revision"):
        if not _text(value.get(key)):
            errors.append(f"{label}.{key} is required")
    water = value.get("water_surface")
    if not isinstance(water, dict):
        errors.append(f"{label}.water_surface must be an object")
    else:
        if not _text(water.get("material_id")) or not _text(water.get("audio_hint")):
            errors.append(f"{label}.water_surface requires material_id and audio_hint")
        if water.get("material_status") not in {"authored", "pending"}:
            errors.append(f"{label}.water_surface.material_status must remain open")
        if water.get("procedural_generation") is not False:
            errors.append(f"{label}.water_surface.procedural_generation must be false")
    shoreline = value.get("shoreline")
    if not isinstance(shoreline, dict):
        errors.append(f"{label}.shoreline must be an object")
    else:
        for key in ("route_id", "surface_material_id", "slope_policy"):
            if not _text(shoreline.get(key)):
                errors.append(f"{label}.shoreline.{key} is required")
        if shoreline.get("review_status") not in OPEN:
            errors.append(f"{label}.shoreline.review_status must remain open")
    hazards = value.get("shoreline_hazards")
    if not isinstance(hazards, list) or not hazards:
        errors.append(f"{label}.shoreline_hazards must contain authored hazards")
        hazards = []
    ids: set[str] = set()
    for index, hazard in enumerate(hazards):
        prefix = f"{label}.shoreline_hazards[{index}]"
        if not isinstance(hazard, dict):
            errors.append(f"{prefix} must be an object")
            continue
        ident = hazard.get("id")
        if not _text(ident) or ident in ids:
            errors.append(f"{prefix}.id must be unique")
        ids.add(ident)
        if hazard.get("kind") not in HAZARD_KINDS:
            errors.append(f"{prefix}.kind is invalid")
        if not _text(hazard.get("recovery_id")) or not _text(hazard.get("route_id")):
            errors.append(f"{prefix} requires recovery_id and route_id")
        if hazard.get("review_status") not in OPEN:
            errors.append(f"{prefix}.review_status must remain open")
    native = value.get("native_render")
    if not isinstance(native, dict) or native.get("status") != "NOT_RUN" or native.get("evidence") is not None:
        errors.append(f"{label}.native_render must remain NOT_RUN without evidence")
    human = value.get("human_review")
    if not isinstance(human, dict) or human.get("status") not in OPEN:
        errors.append(f"{label}.human_review.status must remain open")
    exclusions = value.get("claims_excluded")
    required = {"water_runtime", "hazard_resolution", "native_render", "human_review"}
    if not isinstance(exclusions, list) or not required.issubset(set(exclusions)):
        errors.append(f"{label}.claims_excluded must preserve runtime and review gates")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("ledger", type=Path)
    args = parser.parse_args(argv)
    errors = validate_ledger(json.loads(args.ledger.read_text(encoding="utf-8")))
    if errors:
        print("PLANETARY_WATER_SHORELINE_REVIEW_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PLANETARY_WATER_SHORELINE_REVIEW_VALID_OPEN")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
