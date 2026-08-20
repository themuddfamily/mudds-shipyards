#!/usr/bin/env python3
"""Validate landmark route visual connectivity review records."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

SCHEMA = "planetary_hazard_landmark_visual_connectivity_v1"
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
    markers = value.get("markers")
    if not isinstance(markers, list) or len(markers) < 2:
        errors.append(f"{label}.markers must contain at least two markers")
        markers = []
    marker_ids: set[str] = set()
    for index, marker in enumerate(markers):
        prefix = f"{label}.markers[{index}]"
        if not isinstance(marker, dict):
            errors.append(f"{prefix} must be an object")
            continue
        ident = marker.get("id")
        if not _text(ident) or ident in marker_ids:
            errors.append(f"{prefix}.id must be unique")
        marker_ids.add(ident)
        if not _text(marker.get("capture_id")):
            errors.append(f"{prefix}.capture_id is required")
        if marker.get("visibility_status") not in OPEN:
            errors.append(f"{prefix}.visibility_status must remain open")
    links = value.get("visual_links")
    if not isinstance(links, list) or not links:
        errors.append(f"{label}.visual_links must contain authored links")
        links = []
    link_ids: set[str] = set()
    for index, link in enumerate(links):
        prefix = f"{label}.visual_links[{index}]"
        if not isinstance(link, dict):
            errors.append(f"{prefix} must be an object")
            continue
        ident = link.get("id")
        if not _text(ident) or ident in link_ids:
            errors.append(f"{prefix}.id must be unique")
        link_ids.add(ident)
        if link.get("from_marker") not in marker_ids or link.get("to_marker") not in marker_ids:
            errors.append(f"{prefix} must reference known markers")
        if not _text(link.get("route_id")) or not _text(link.get("hazard_id")):
            errors.append(f"{prefix} requires route_id and hazard_id")
        if not _text(link.get("capture_id")):
            errors.append(f"{prefix}.capture_id is required")
        if link.get("review_status") not in OPEN:
            errors.append(f"{prefix}.review_status must remain open")
        if link.get("runtime_navigation") is not False:
            errors.append(f"{prefix}.runtime_navigation must be false")
    gates = value.get("gates")
    if not isinstance(gates, dict):
        errors.append(f"{label}.gates must be an object")
    else:
        for key in ("native_render", "human_review"):
            if not isinstance(gates.get(key), dict) or gates[key].get("status") not in OPEN:
                errors.append(f"{label}.gates.{key}.status must remain open")
    exclusions = value.get("claims_excluded")
    if not isinstance(exclusions, list) or not {"runtime_navigation", "native_render", "human_review"}.issubset(set(exclusions)):
        errors.append(f"{label}.claims_excluded must preserve all open gates")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("index", type=Path)
    args = parser.parse_args(argv)
    errors = validate_index(json.loads(args.index.read_text(encoding="utf-8")))
    if errors:
        print("PLANETARY_HAZARD_VISUAL_CONNECTIVITY_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PLANETARY_HAZARD_VISUAL_CONNECTIVITY_VALID_OPEN")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
