#!/usr/bin/env python3
"""Validate authored settlement hazard return-route visual evidence."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

SCHEMA = "planetary_settlement_hazard_return_route_v1"
OPEN = {"pending", "not_performed"}


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
    routes = value.get("return_routes")
    if not isinstance(routes, list) or not routes:
        errors.append(f"{label}.return_routes must contain authored return routes")
        routes = []
    route_ids: set[str] = set()
    for index, route in enumerate(routes):
        prefix = f"{label}.return_routes[{index}]"
        if not isinstance(route, dict):
            errors.append(f"{prefix} must be an object")
            continue
        ident = route.get("id")
        if not _text(ident) or ident in route_ids:
            errors.append(f"{prefix}.id must be unique")
        route_ids.add(ident)
        for key in ("hazard_id", "safe_anchor_id", "return_anchor_id", "capture_id"):
            if not _text(route.get(key)):
                errors.append(f"{prefix}.{key} is required")
        if not _text(route.get("scene_path")) or not route["scene_path"].startswith("res://"):
            errors.append(f"{prefix}.scene_path must be a res:// path")
        if route.get("review_status") not in OPEN:
            errors.append(f"{prefix}.review_status must remain open")
        if route.get("runtime_teleport") is not False:
            errors.append(f"{prefix}.runtime_teleport must be false")
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
        if hazard.get("return_route_id") not in route_ids:
            errors.append(f"{prefix}.return_route_id must reference a return route")
        if hazard.get("evidence_status") not in OPEN:
            errors.append(f"{prefix}.evidence_status must remain open")
    for route in routes:
        if isinstance(route, dict) and route.get("hazard_id") not in hazard_ids:
            errors.append(f"return route hazard_id must reference an authored hazard: {route.get('hazard_id')}")
    for key in ("native_render", "human_review"):
        gate = value.get(key)
        if not isinstance(gate, dict) or gate.get("status") not in OPEN:
            errors.append(f"{label}.{key}.status must remain open")
    exclusions = value.get("claims_excluded")
    if not isinstance(exclusions, list) or not {"runtime_teleport", "native_render", "human_review"}.issubset(set(exclusions)):
        errors.append(f"{label}.claims_excluded must preserve all open gates")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("index", type=Path)
    args = parser.parse_args(argv)
    errors = validate_index(json.loads(args.index.read_text(encoding="utf-8")))
    if errors:
        print("PLANETARY_HAZARD_RETURN_ROUTE_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PLANETARY_HAZARD_RETURN_ROUTE_VALID_OPEN")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
