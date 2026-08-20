#!/usr/bin/env python3
"""Validate planetary settlement route and landmark visual evidence."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

SCHEMA = "planetary_settlement_route_landmark_index_v1"
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
    nodes = value.get("route_nodes")
    if not isinstance(nodes, list) or len(nodes) < 2:
        errors.append(f"{label}.route_nodes must contain at least two nodes")
        nodes = []
    node_ids: set[str] = set()
    for index, node in enumerate(nodes):
        prefix = f"{label}.route_nodes[{index}]"
        if not isinstance(node, dict):
            errors.append(f"{prefix} must be an object")
            continue
        ident = node.get("id")
        if not _text(ident) or ident in node_ids:
            errors.append(f"{prefix}.id must be unique")
        node_ids.add(ident)
        if not _text(node.get("scene_path")) or not node["scene_path"].startswith("res://"):
            errors.append(f"{prefix}.scene_path must be a res:// path")
        if node.get("review_status") not in OPEN:
            errors.append(f"{prefix}.review_status must remain open")
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
        if route.get("from_node") not in node_ids or route.get("to_node") not in node_ids:
            errors.append(f"{prefix} must reference known route nodes")
        if not _text(route.get("landmark_id")):
            errors.append(f"{prefix}.landmark_id is required")
        if route.get("evidence_status") not in OPEN:
            errors.append(f"{prefix}.evidence_status must remain open")
    landmarks = value.get("landmarks")
    if not isinstance(landmarks, list) or not landmarks:
        errors.append(f"{label}.landmarks must contain authored landmarks")
        landmarks = []
    landmark_ids: set[str] = set()
    for index, landmark in enumerate(landmarks):
        prefix = f"{label}.landmarks[{index}]"
        if not isinstance(landmark, dict):
            errors.append(f"{prefix} must be an object")
            continue
        ident = landmark.get("id")
        if not _text(ident) or ident in landmark_ids:
            errors.append(f"{prefix}.id must be unique")
        landmark_ids.add(ident)
        if landmark.get("node_id") not in node_ids:
            errors.append(f"{prefix}.node_id must reference a known route node")
        if landmark.get("procedural_generation") is not False:
            errors.append(f"{prefix}.procedural_generation must be false")
        if landmark.get("review_status") not in OPEN:
            errors.append(f"{prefix}.review_status must remain open")
    for route in routes:
        if isinstance(route, dict) and route.get("landmark_id") not in landmark_ids:
            errors.append(f"route landmark_id must reference an authored landmark: {route.get('landmark_id')}")
    for key in ("native_render", "human_review"):
        gate = value.get(key)
        if not isinstance(gate, dict) or gate.get("status") not in OPEN:
            errors.append(f"{label}.{key}.status must remain open")
    exclusions = value.get("claims_excluded")
    if not isinstance(exclusions, list) or not {"native_render", "human_review", "route_runtime"}.issubset(set(exclusions)):
        errors.append(f"{label}.claims_excluded must preserve all open gates")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("index", type=Path)
    args = parser.parse_args(argv)
    errors = validate_index(json.loads(args.index.read_text(encoding="utf-8")))
    if errors:
        print("PLANETARY_SETTLEMENT_ROUTE_LANDMARK_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PLANETARY_SETTLEMENT_ROUTE_LANDMARK_VALID_OPEN")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
