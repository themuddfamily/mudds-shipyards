#!/usr/bin/env python3
"""Validate authored hazard-route landmark visual evidence."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

SCHEMA = "planetary_hazard_route_landmark_visual_v1"
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
        if not _text(landmark.get("scene_path")) or not landmark["scene_path"].startswith("res://"):
            errors.append(f"{prefix}.scene_path must be a res:// path")
        if not _text(landmark.get("route_id")) or not _text(landmark.get("capture_id")):
            errors.append(f"{prefix} requires route_id and capture_id")
        if landmark.get("review_status") not in OPEN:
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
        if hazard.get("landmark_id") not in landmark_ids:
            errors.append(f"{prefix}.landmark_id must reference an authored landmark")
        if hazard.get("review_status") not in OPEN:
            errors.append(f"{prefix}.review_status must remain open")
        if not _text(hazard.get("recovery_id")):
            errors.append(f"{prefix}.recovery_id is required")
    for key in ("native_render", "human_review"):
        gate = value.get(key)
        if not isinstance(gate, dict) or gate.get("status") not in OPEN:
            errors.append(f"{label}.{key}.status must remain open")
    exclusions = value.get("claims_excluded")
    if not isinstance(exclusions, list) or not {"hazard_runtime", "native_render", "human_review"}.issubset(set(exclusions)):
        errors.append(f"{label}.claims_excluded must preserve all open gates")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("index", type=Path)
    args = parser.parse_args(argv)
    errors = validate_index(json.loads(args.index.read_text(encoding="utf-8")))
    if errors:
        print("PLANETARY_HAZARD_LANDMARK_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PLANETARY_HAZARD_LANDMARK_VALID_OPEN")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
