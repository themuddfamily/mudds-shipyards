#!/usr/bin/env python3
"""Validate a planetary settlement landmark visual evidence rollup."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

SCHEMA = "planetary_visual_settlement_landmark_rollup_v1"
LANDMARK_KINDS = {"landing_pad", "relay", "sample_station", "overlook", "habitat"}
OPEN = {"pending", "not_performed"}


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def validate_rollup(value: Any, label: str = "rollup") -> list[str]:
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema") != SCHEMA:
        errors.append(f"{label}.schema must be {SCHEMA}")
    for key in ("world_id", "region_id", "source_revision"):
        if not _text(value.get(key)):
            errors.append(f"{label}.{key} is required")
    landmarks = value.get("landmarks")
    if not isinstance(landmarks, list) or len(landmarks) < 3:
        errors.append(f"{label}.landmarks must contain at least three authored landmarks")
        landmarks = []
    ids: set[str] = set()
    kinds: set[str] = set()
    for index, landmark in enumerate(landmarks):
        prefix = f"{label}.landmarks[{index}]"
        if not isinstance(landmark, dict):
            errors.append(f"{prefix} must be an object")
            continue
        ident = landmark.get("id")
        if not _text(ident) or ident in ids:
            errors.append(f"{prefix}.id must be unique")
        ids.add(ident)
        kind = landmark.get("kind")
        if kind not in LANDMARK_KINDS:
            errors.append(f"{prefix}.kind is invalid")
        kinds.add(kind)
        if not _text(landmark.get("route_id")) or not _text(landmark.get("scene_path")):
            errors.append(f"{prefix} requires route_id and scene_path")
        if not str(landmark.get("scene_path", "")).startswith("res://"):
            errors.append(f"{prefix}.scene_path must be a res:// path")
        if landmark.get("review_status") not in OPEN:
            errors.append(f"{prefix}.review_status must remain open")
        if landmark.get("procedural_generation") is not False:
            errors.append(f"{prefix}.procedural_generation must be false")
    if not {"landing_pad", "relay"}.issubset(kinds):
        errors.append(f"{label}.landmarks must include a landing_pad and relay")
    capture = value.get("capture_evidence")
    if not isinstance(capture, dict) or capture.get("status") not in OPEN:
        errors.append(f"{label}.capture_evidence.status must remain open")
    elif capture.get("status") == "not_performed" and capture.get("record") is not None:
        errors.append(f"{label}.capture_evidence.record must be null when not_performed")
    for key in ("native_render", "human_review"):
        gate = value.get(key)
        if not isinstance(gate, dict) or gate.get("status") not in OPEN:
            errors.append(f"{label}.{key}.status must remain open")
    exclusions = value.get("claims_excluded")
    if not isinstance(exclusions, list) or not {"native_render", "human_review", "production_settlement"}.issubset(set(exclusions)):
        errors.append(f"{label}.claims_excluded must preserve all open gates")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("rollup", type=Path)
    args = parser.parse_args(argv)
    errors = validate_rollup(json.loads(args.rollup.read_text(encoding="utf-8")))
    if errors:
        print("PLANETARY_LANDMARK_ROLLUP_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PLANETARY_LANDMARK_ROLLUP_VALID_OPEN")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
