#!/usr/bin/env python3
"""Validate planetary settlement hazard/route visual evidence."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

SCHEMA = "planetary_settlement_hazard_route_visual_v1"
OPEN = {"pending", "not_performed"}
KINDS = {"unstable_terrain", "exposed_reactor", "collapsed_structure", "dust_surge"}


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def validate_index(value: Any, label: str = "index") -> list[str]:
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema") != SCHEMA:
        errors.append(f"{label}.schema must be {SCHEMA}")
    for key in ("world_id", "settlement_id", "source_revision"):
        if not _text(value.get(key)):
            errors.append(f"{label}.{key} is required")
    routes = value.get("routes")
    if not isinstance(routes, list) or not routes:
        errors.append(f"{label}.routes must contain authored routes")
        routes = []
    route_ids: set[str] = set()
    for index, route in enumerate(routes):
        prefix = f"{label}.routes[{index}]"
        if not isinstance(route, dict):
            errors.append(f"{prefix} must be an object")
            continue
        ident = route.get("id")
        if not _text(ident) or ident in route_ids:
            errors.append(f"{prefix}.id must be unique")
        route_ids.add(ident)
        if not _text(route.get("from_marker")) or not _text(route.get("to_marker")):
            errors.append(f"{prefix} requires from_marker and to_marker")
        if not _text(route.get("capture_id")):
            errors.append(f"{prefix}.capture_id is required")
        if route.get("review_status") not in OPEN:
            errors.append(f"{prefix}.review_status must remain open")
    hazards = value.get("hazards")
    if not isinstance(hazards, list) or not hazards:
        errors.append(f"{label}.hazards must contain authored hazards")
        hazards = []
    hazard_ids: set[str] = set()
    for index, hazard in enumerate(hazards):
        prefix = f"{label}.hazards[{index}]"
        if not isinstance(hazard, dict):
            errors.append(f"{prefix} must be an object")
            continue
        ident = hazard.get("id")
        if not _text(ident) or ident in hazard_ids:
            errors.append(f"{prefix}.id must be unique")
        hazard_ids.add(ident)
        if hazard.get("kind") not in KINDS:
            errors.append(f"{prefix}.kind is invalid")
        if hazard.get("route_id") not in route_ids:
            errors.append(f"{prefix}.route_id must reference an authored route")
        if not _text(hazard.get("recovery_id")) or not _text(hazard.get("capture_id")):
            errors.append(f"{prefix} requires recovery_id and capture_id")
        if hazard.get("review_status") not in OPEN:
            errors.append(f"{prefix}.review_status must remain open")
        if hazard.get("runtime_resolution") != "external_hazard_authority":
            errors.append(f"{prefix}.runtime_resolution must remain external")
    for key in ("native_render", "human_review"):
        gate = value.get(key)
        if not isinstance(gate, dict) or gate.get("status") not in OPEN:
            errors.append(f"{label}.{key}.status must remain open")
    exclusions = value.get("claims_excluded")
    if not isinstance(exclusions, list) or not {"hazard_runtime", "native_render", "human_review"}.issubset(set(exclusions)):
        errors.append(f"{label}.claims_excluded must preserve runtime and review exclusions")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("index", type=Path)
    args = parser.parse_args(argv)
    errors = validate_index(json.loads(args.index.read_text(encoding="utf-8")))
    if errors:
        print("PLANETARY_SETTLEMENT_HAZARD_ROUTE_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PLANETARY_SETTLEMENT_HAZARD_ROUTE_VALID_OPEN")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
