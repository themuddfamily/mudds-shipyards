#!/usr/bin/env python3
"""Validate a fleet/planetary visual human-review evidence index."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

SCHEMA = "fleet_planetary_visual_review_index_v1"
KINDS = {"fleet_ship", "planetary_surface", "planetary_settlement", "planetary_sky"}
OPEN = {"pending", "not_performed"}


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def validate_index(value: Any, label: str = "index") -> list[str]:
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema") != SCHEMA:
        errors.append(f"{label}.schema must be {SCHEMA}")
    if not _text(value.get("source_revision")) or not _text(value.get("reviewer_role")):
        errors.append(f"{label}.source_revision and reviewer_role are required")
    entries = value.get("entries")
    if not isinstance(entries, list) or len(entries) < 2:
        errors.append(f"{label}.entries must contain fleet and planetary records")
        entries = []
    seen: set[str] = set()
    kinds: set[str] = set()
    for index, entry in enumerate(entries):
        prefix = f"{label}.entries[{index}]"
        if not isinstance(entry, dict):
            errors.append(f"{prefix} must be an object")
            continue
        ident = entry.get("id")
        if not _text(ident) or ident in seen:
            errors.append(f"{prefix}.id must be unique")
        seen.add(ident)
        kind = entry.get("kind")
        if kind not in KINDS:
            errors.append(f"{prefix}.kind is invalid")
        kinds.add(kind)
        if not _text(entry.get("scene_path")) or not entry["scene_path"].startswith("res://"):
            errors.append(f"{prefix}.scene_path must be a res:// path")
        if not _text(entry.get("capture_id")):
            errors.append(f"{prefix}.capture_id is required")
        if entry.get("review_status") not in OPEN:
            errors.append(f"{prefix}.review_status must remain open")
        if entry.get("historical_claim") is not False:
            errors.append(f"{prefix}.historical_claim must be false")
    if not {"fleet_ship", "planetary_surface"}.issubset(kinds):
        errors.append(f"{label}.entries must include fleet and planetary visual evidence")
    human = value.get("human_visual_review")
    if not isinstance(human, dict) or human.get("status") not in OPEN:
        errors.append(f"{label}.human_visual_review.status must remain open")
    elif human.get("status") == "not_performed" and human.get("evidence") is not None:
        errors.append(f"{label}.human_visual_review.evidence must be null when not_performed")
    native = value.get("native_render")
    if not isinstance(native, dict) or native.get("status") != "NOT_RUN" or native.get("evidence") is not None:
        errors.append(f"{label}.native_render must remain NOT_RUN without evidence")
    exclusions = value.get("claims_excluded")
    if not isinstance(exclusions, list) or not {"human_visual_signoff", "native_render"}.issubset(set(exclusions)):
        errors.append(f"{label}.claims_excluded must preserve human and native gates")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("index", type=Path)
    args = parser.parse_args(argv)
    errors = validate_index(json.loads(args.index.read_text(encoding="utf-8")))
    if errors:
        print("FLEET_PLANETARY_VISUAL_REVIEW_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("FLEET_PLANETARY_VISUAL_REVIEW_VALID_OPEN")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
