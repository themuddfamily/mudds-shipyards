#!/usr/bin/env python3
"""Validate visual evidence for hazard-landmark route connectivity."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

SCHEMA = "planetary_hazard_landmark_route_connectivity_v1"
OPEN = {"pending", "not_performed"}


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def validate_index(value: Any, label: str = "index") -> list[str]:
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema") != SCHEMA:
        errors.append(f"{label}.schema must be {SCHEMA}")
    for key in ("world_id", "region_id", "source_revision"):
        if not _text(value.get(key)):
            errors.append(f"{label}.{key} is required")
    landmarks = value.get("landmarks")
    if not isinstance(landmarks, list) or len(landmarks) < 2:
        errors.append(f"{label}.landmarks must contain at least two landmarks")
        landmarks = []
    ids: set[str] = set()
    for index, landmark in enumerate(landmarks):
        prefix = f"{label}.landmarks[{index}]"
        if not isinstance(landmark, dict):
            errors.append(f"{prefix} must be an object")
            continue
        ident = landmark.get("id")
        if not _text(ident) or ident in ids:
            errors.append(f"{prefix}.id must be unique")
        ids.add(ident)
        if landmark.get("role") not in {"landing_pad", "hazard_anchor", "recovery_anchor"}:
            errors.append(f"{prefix}.role is invalid")
        if not _text(landmark.get("capture_id")):
            errors.append(f"{prefix}.capture_id is required")
        if landmark.get("review_status") not in OPEN:
            errors.append(f"{prefix}.review_status must remain open")
    routes = value.get("routes")
    if not isinstance(routes, list) or not routes:
        errors.append(f"{label}.routes must contain authored connections")
        routes = []
    route_ids: set[str] = set()
    adjacency: dict[str, set[str]] = {ident: set() for ident in ids}
    for index, route in enumerate(routes):
        prefix = f"{label}.routes[{index}]"
        if not isinstance(route, dict):
            errors.append(f"{prefix} must be an object")
            continue
        ident = route.get("id")
        if not _text(ident) or ident in route_ids:
            errors.append(f"{prefix}.id must be unique")
        route_ids.add(ident)
        source, target = route.get("from_landmark"), route.get("to_landmark")
        if source not in ids or target not in ids:
            errors.append(f"{prefix} must reference known landmarks")
        else:
            adjacency[source].add(target)
        if not _text(route.get("hazard_id")) or not _text(route.get("capture_id")):
            errors.append(f"{prefix} requires hazard_id and capture_id")
        if route.get("review_status") not in OPEN:
            errors.append(f"{prefix}.review_status must remain open")
        if not isinstance(route.get("distance_m"), (int, float)) or route.get("distance_m") <= 0:
            errors.append(f"{prefix}.distance_m must be positive")
    roots = [item.get("id") for item in landmarks if isinstance(item, dict) and item.get("role") == "landing_pad"]
    reachable = set(roots[:1])
    changed = True
    while changed:
        changed = False
        for source in tuple(reachable):
            before = len(reachable)
            reachable.update(adjacency.get(source, set()))
            changed |= len(reachable) != before
    if ids and (not roots or reachable != ids):
        errors.append(f"{label}.connectivity must reach every landmark from landing_pad")
    for key in ("native_render", "human_review"):
        gate = value.get(key)
        if not isinstance(gate, dict) or gate.get("status") not in OPEN:
            errors.append(f"{label}.{key}.status must remain open")
    exclusions = value.get("claims_excluded")
    if not isinstance(exclusions, list) or not {"route_runtime", "native_render", "human_review"}.issubset(set(exclusions)):
        errors.append(f"{label}.claims_excluded must preserve all open gates")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("index", type=Path)
    args = parser.parse_args(argv)
    errors = validate_index(json.loads(args.index.read_text(encoding="utf-8")))
    if errors:
        print("PLANETARY_HAZARD_ROUTE_CONNECTIVITY_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PLANETARY_HAZARD_ROUTE_CONNECTIVITY_VALID_OPEN")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
