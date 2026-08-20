#!/usr/bin/env python3
"""Validate a planetary settlement visual/human review evidence ledger.

This is a review handoff only.  It keeps human approval open and does not
declare authored settlement art production-ready.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

SCHEMA = "planetary_settlement_visual_review_v1"
VIEWS = ("approach", "surface", "interior")
OPEN = {"pending", "not_performed"}


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def validate_ledger(value: Any, label: str = "ledger") -> list[str]:
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema") != SCHEMA:
        errors.append(f"{label}.schema must be {SCHEMA}")
    for key in ("world_id", "settlement_id", "source_revision", "reviewer_role"):
        if not _text(value.get(key)):
            errors.append(f"{label}.{key} is required")
    structures = value.get("structures")
    if not isinstance(structures, list) or not structures:
        errors.append(f"{label}.structures must contain at least one authored structure")
        structures = []
    seen: set[str] = set()
    for index, structure in enumerate(structures):
        prefix = f"{label}.structures[{index}]"
        if not isinstance(structure, dict):
            errors.append(f"{prefix} must be an object")
            continue
        ident = structure.get("id")
        if not _text(ident) or ident in seen:
            errors.append(f"{prefix}.id must be unique non-empty text")
        seen.add(ident)
        if not _text(structure.get("scene_path")) or not structure["scene_path"].startswith("res://"):
            errors.append(f"{prefix}.scene_path must be a res:// path")
        if not _text(structure.get("role")):
            errors.append(f"{prefix}.role is required")
        if structure.get("authored_status") not in {"authored", "placeholder"}:
            errors.append(f"{prefix}.authored_status is invalid")
    captures = value.get("view_captures")
    if not isinstance(captures, list) or len(captures) != len(VIEWS):
        errors.append(f"{label}.view_captures must contain approach, surface, and interior")
        captures = captures if isinstance(captures, list) else []
    seen_views: set[str] = set()
    for index, capture in enumerate(captures):
        prefix = f"{label}.view_captures[{index}]"
        if not isinstance(capture, dict):
            errors.append(f"{prefix} must be an object")
            continue
        view = capture.get("view")
        if view not in VIEWS or view in seen_views:
            errors.append(f"{prefix}.view must be unique and ordered")
        seen_views.add(view)
        if view != VIEWS[index] if index < len(VIEWS) else True:
            errors.append(f"{prefix}.view is out of order")
        if not _text(capture.get("capture_path")) or not capture["capture_path"].startswith("res://"):
            errors.append(f"{prefix}.capture_path must be a res:// path")
        if capture.get("review_status") not in OPEN:
            errors.append(f"{prefix}.review_status must remain open")
        if capture.get("evidence") is not None and not _text(capture.get("evidence")):
            errors.append(f"{prefix}.evidence must be non-empty when provided")
    human = value.get("human_signoff")
    if not isinstance(human, dict) or human.get("status") not in OPEN or human.get("status") == "approved":
        errors.append(f"{label}.human_signoff.status must remain pending or not_performed")
    elif human.get("status") == "not_performed" and human.get("evidence") is not None:
        errors.append(f"{label}.human_signoff.evidence must be null when not_performed")
    exclusions = value.get("claims_excluded")
    if not isinstance(exclusions, list) or "human_visual_approval" not in exclusions or "production_art_signoff" not in exclusions:
        errors.append(f"{label}.claims_excluded must preserve human and production-art gates")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("ledger", type=Path)
    args = parser.parse_args(argv)
    errors = validate_ledger(json.loads(args.ledger.read_text(encoding="utf-8")))
    if errors:
        print("PLANETARY_SETTLEMENT_REVIEW_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PLANETARY_SETTLEMENT_REVIEW_VALID_OPEN")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
