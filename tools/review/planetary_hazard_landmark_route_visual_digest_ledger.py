#!/usr/bin/env python3
"""Validate visual capture digests for authored hazard landmark routes."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

SCHEMA = "planetary_hazard_landmark_route_visual_digest_v1"
OPEN = {"pending", "not_performed"}
SHA256 = re.compile(r"^[0-9a-fA-F]{64}$")


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
    captures = value.get("captures")
    if not isinstance(captures, list) or not captures:
        errors.append(f"{label}.captures must contain authored captures")
        captures = []
    capture_ids: set[str] = set()
    for index, capture in enumerate(captures):
        prefix = f"{label}.captures[{index}]"
        if not isinstance(capture, dict):
            errors.append(f"{prefix} must be an object")
            continue
        ident = capture.get("id")
        if not _text(ident) or ident in capture_ids:
            errors.append(f"{prefix}.id must be unique")
        capture_ids.add(ident)
        if not _text(capture.get("path")) or not capture["path"].startswith("res://"):
            errors.append(f"{prefix}.path must be a res:// path")
        if not isinstance(capture.get("sha256"), str) or not SHA256.fullmatch(capture["sha256"]):
            errors.append(f"{prefix}.sha256 must be a 64-character hex digest")
        if capture.get("review_status") not in OPEN:
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
        if route.get("capture_id") not in capture_ids:
            errors.append(f"{prefix}.capture_id must reference a capture")
        if not _text(route.get("hazard_id")) or not _text(route.get("landmark_id")):
            errors.append(f"{prefix} requires hazard_id and landmark_id")
        if route.get("review_status") not in OPEN:
            errors.append(f"{prefix}.review_status must remain open")
    for key in ("native_render", "human_review"):
        gate = value.get(key)
        if not isinstance(gate, dict) or gate.get("status") not in OPEN:
            errors.append(f"{label}.{key}.status must remain open")
    exclusions = value.get("claims_excluded")
    if not isinstance(exclusions, list) or not {"capture_verification", "native_render", "human_review"}.issubset(set(exclusions)):
        errors.append(f"{label}.claims_excluded must preserve all open gates")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("ledger", type=Path)
    args = parser.parse_args(argv)
    errors = validate_ledger(json.loads(args.ledger.read_text(encoding="utf-8")))
    if errors:
        print("PLANETARY_HAZARD_VISUAL_DIGEST_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PLANETARY_HAZARD_VISUAL_DIGEST_VALID_OPEN")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
