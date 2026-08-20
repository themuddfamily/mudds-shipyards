#!/usr/bin/env python3
"""Validate v2 review metadata for planetary visual digest counts."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

SCHEMA = "planetary_hazard_visual_digest_summary_count_review_v2"
OPEN = {"pending", "not_performed"}
KINDS = ("hazard", "landmark", "route")


def validate_review(value: Any, label: str = "review") -> list[str]:
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema") != SCHEMA:
        errors.append(f"{label}.schema must be {SCHEMA}")
    for key in ("world_id", "region_id", "source_revision", "reviewer_role"):
        if not isinstance(value.get(key), str) or not value[key].strip():
            errors.append(f"{label}.{key} is required")
    categories = value.get("categories")
    if not isinstance(categories, list) or len(categories) != len(KINDS):
        errors.append(f"{label}.categories must contain hazard, landmark, and route")
        categories = categories if isinstance(categories, list) else []
    seen: set[str] = set()
    for index, category in enumerate(categories):
        prefix = f"{label}.categories[{index}]"
        if not isinstance(category, dict):
            errors.append(f"{prefix} must be an object")
            continue
        kind = category.get("kind")
        if kind not in KINDS or kind in seen:
            errors.append(f"{prefix}.kind must be unique and valid")
        seen.add(kind)
        count = category.get("count")
        if not isinstance(count, int) or isinstance(count, bool) or count < 1:
            errors.append(f"{prefix}.count must be positive")
        if not isinstance(category.get("review_prompt"), str) or not category["review_prompt"].strip():
            errors.append(f"{prefix}.review_prompt is required")
        if category.get("status") not in OPEN:
            errors.append(f"{prefix}.status must remain open")
    summary = value.get("summary_status")
    if summary not in OPEN:
        errors.append(f"{label}.summary_status must remain open")
    for key in ("native_render", "human_signoff"):
        gate = value.get(key)
        if not isinstance(gate, dict) or gate.get("status") not in OPEN:
            errors.append(f"{label}.{key}.status must remain open")
    exclusions = value.get("claims_excluded")
    if not isinstance(exclusions, list) or not {"count_review", "native_render", "human_signoff"}.issubset(set(exclusions)):
        errors.append(f"{label}.claims_excluded must preserve all open gates")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("review", type=Path)
    args = parser.parse_args(argv)
    errors = validate_review(json.loads(args.review.read_text(encoding="utf-8")))
    if errors:
        print("PLANETARY_DIGEST_COUNT_REVIEW_V2_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PLANETARY_DIGEST_COUNT_REVIEW_V2_VALID_OPEN")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
