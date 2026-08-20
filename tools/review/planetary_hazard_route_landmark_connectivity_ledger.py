#!/usr/bin/env python3
"""Validate authored hazard-route landmark connectivity visual evidence."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

SCHEMA = "planetary_hazard_route_landmark_connectivity_v1"
OPEN = {"pending", "not_performed"}


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
    landmarks = value.get("landmarks")
    if not isinstance(landmarks, list) or not landmarks:
        errors.append(f"{label}.landmarks must contain authored landmarks")
        landmarks = []
    landmark_ids: set[str] = set()
    adjacency: dict[str, set[str]] = {}
    for index, landmark in enumerate(landmarks):
        prefix = f"{label}.landmarks[{index}]"
        if not isinstance(landmark, dict) or not _text(landmark.get("id")):
            errors.append(f"{prefix}.id is required")
            continue
        ident = landmark["id"]
        if ident in landmark_ids:
            errors.append(f"{prefix}.id must be unique")
        landmark_ids.add(ident)
        adjacency[ident] = set()
        if not _text(landmark.get("capture_id")):
            errors.append(f"{prefix}.capture_id is required")
        if landmark.get("review_status") not in OPEN:
            errors.append(f"{prefix}.review_status must remain open")
    edges = value.get("edges")
    if not isinstance(edges, list) or not edges:
        errors.append(f"{label}.edges must contain authored connections")
        edges = []
    for index, edge in enumerate(edges):
        prefix = f"{label}.edges[{index}]"
        if not isinstance(edge, dict):
            errors.append(f"{prefix} must be an object")
            continue
        source, target = edge.get("from_landmark"), edge.get("to_landmark")
        if source not in landmark_ids or target not in landmark_ids:
            errors.append(f"{prefix} must reference known landmarks")
        else:
            adjacency[source].add(target)
        if not _text(edge.get("route_id")) or not _text(edge.get("capture_id")):
            errors.append(f"{prefix} requires route_id and capture_id")
        if edge.get("review_status") not in OPEN:
            errors.append(f"{prefix}.review_status must remain open")
    roots = [item.get("id") for item in landmarks if isinstance(item, dict) and item.get("role") == "landing_pad"]
    reachable = set(roots[:1])
    changed = True
    while changed:
        changed = False
        for source in tuple(reachable):
            before = len(reachable)
            reachable.update(adjacency.get(source, set()))
            changed |= len(reachable) != before
    if landmark_ids and (not roots or reachable != landmark_ids):
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
    parser.add_argument("ledger", type=Path)
    args = parser.parse_args(argv)
    errors = validate_ledger(json.loads(args.ledger.read_text(encoding="utf-8")))
    if errors:
        print("PLANETARY_HAZARD_CONNECTIVITY_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PLANETARY_HAZARD_CONNECTIVITY_VALID_OPEN")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
