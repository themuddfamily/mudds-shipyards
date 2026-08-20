#!/usr/bin/env python3
"""Validate a geometry-audit handoff without pretending to inspect pixels.

The manifest records what was inspected from the embodied player and ship
viewpoints.  It is deliberately an evidence contract: a local validator can
check coverage and traceability, but clipping, readability, and route quality
still require a human review in the running game.
"""

from __future__ import annotations

import json
from pathlib import Path

SCHEMA = "embodied_geometry_audit_v1"
PERSPECTIVES = {"embodied_player", "ship"}
RESULTS = {"clear", "observed", "not_assessed"}
CATEGORIES = {
    "clipping",
    "camera_near_plane_intrusion",
    "z_fighting",
    "invisible_blocker",
    "collision_free_dressing",
    "inaccessible_route",
    "flashing_material_or_light",
    "lifecycle_phantom_geometry",
}


def validate(manifest_path: Path) -> list[str]:
    """Return blocking errors; an empty list means ready for human review."""
    try:
        data = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"manifest unreadable: {exc}"]

    errors: list[str] = []
    required = ("schema", "source_revision", "human_review_status",
                "reviewer_required", "viewpoints", "observations")
    errors.extend(f"manifest missing required key: {key}" for key in required if key not in data)
    if errors:
        return errors
    if data["schema"] != SCHEMA:
        errors.append(f"unsupported schema: {data['schema']!r}")
    if not isinstance(data["source_revision"], str) or not data["source_revision"].strip():
        errors.append("source_revision must identify the audited build or commit")

    status = data["human_review_status"]
    if status not in {"pending", "not_performed"}:
        errors.append("human_review_status must be pending or not_performed; automated validation cannot approve geometry")
    reviewer = data["reviewer_required"]
    if not isinstance(reviewer, str) or not reviewer.strip():
        errors.append("reviewer_required must identify the manual reviewer role")

    viewpoints = data["viewpoints"]
    viewpoint_ids: set[str] = set()
    perspectives: set[str] = set()
    if not isinstance(viewpoints, list) or not viewpoints:
        errors.append("viewpoints must contain at least one embodied-player or ship viewpoint")
        viewpoints = []
    for viewpoint in viewpoints:
        if not isinstance(viewpoint, dict):
            errors.append("each viewpoint must be an object")
            continue
        identifier = viewpoint.get("id")
        if not isinstance(identifier, str) or not identifier.strip() or identifier in viewpoint_ids:
            errors.append(f"viewpoint id missing or duplicated: {identifier!r}")
            continue
        viewpoint_ids.add(identifier)
        perspective = viewpoint.get("perspective")
        if perspective not in PERSPECTIVES:
            errors.append(f"{identifier}: perspective must be embodied_player or ship")
        else:
            perspectives.add(perspective)
        for key in ("location", "route"):
            if not isinstance(viewpoint.get(key), str) or not viewpoint[key].strip():
                errors.append(f"{identifier}: {key} is required for audit traceability")
    missing_perspectives = PERSPECTIVES - perspectives
    if missing_perspectives:
        errors.append("viewpoint coverage missing: " + ", ".join(sorted(missing_perspectives)))

    observations = data["observations"]
    seen_categories: set[str] = set()
    if not isinstance(observations, list) or not observations:
        errors.append("observations must contain one assessment for every geometry category")
        observations = []
    for observation in observations:
        if not isinstance(observation, dict):
            errors.append("each observation must be an object")
            continue
        category = observation.get("category")
        if category not in CATEGORIES:
            errors.append(f"unknown geometry observation category: {category!r}")
        else:
            seen_categories.add(category)
        viewpoint = observation.get("viewpoint")
        if viewpoint not in viewpoint_ids:
            errors.append(f"observation references unknown viewpoint: {viewpoint!r}")
        if observation.get("result") not in RESULTS:
            errors.append(f"{category!r}: result must be clear, observed, or not_assessed")
        evidence = observation.get("evidence")
        if not isinstance(evidence, str) or not evidence.strip():
            errors.append(f"{category!r}: evidence is required (path, capture, or reproducible note)")
    missing_categories = CATEGORIES - seen_categories
    if missing_categories:
        errors.append("observation coverage missing: " + ", ".join(sorted(missing_categories)))
    return errors


def main() -> int:
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    args = parser.parse_args()
    errors = validate(args.manifest.resolve())
    if errors:
        for error in errors:
            print(f"EMBODIED_GEOMETRY_AUDIT_FAILED: {error}")
        return 1
    print(f"EMBODIED_GEOMETRY_AUDIT_READY: {args.manifest} (human review still required)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
