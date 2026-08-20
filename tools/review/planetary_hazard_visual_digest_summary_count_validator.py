#!/usr/bin/env python3
"""Validate counts and coverage in a planetary hazard visual digest summary."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

SCHEMA = "planetary_hazard_visual_digest_summary_count_v1"
OPEN = {"pending", "not_performed"}
CATEGORIES = ("hazard", "landmark", "route")


def validate_counts(value: Any, label: str = "summary") -> list[str]:
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema") != SCHEMA:
        errors.append(f"{label}.schema must be {SCHEMA}")
    for key in ("world_id", "region_id", "source_revision"):
        if not isinstance(value.get(key), str) or not value[key].strip():
            errors.append(f"{label}.{key} is required")
    counts = value.get("counts")
    if not isinstance(counts, dict):
        errors.append(f"{label}.counts must be an object")
        counts = {}
    for category in CATEGORIES:
        count = counts.get(category)
        if not isinstance(count, int) or isinstance(count, bool) or count < 1:
            errors.append(f"{label}.counts.{category} must be positive")
    total = counts.get("total")
    if not isinstance(total, int) or isinstance(total, bool) or total < 3:
        errors.append(f"{label}.counts.total must be at least three")
    elif all(isinstance(counts.get(category), int) and not isinstance(counts.get(category), bool) for category in CATEGORIES) and total != sum(counts[category] for category in CATEGORIES):
        errors.append(f"{label}.counts.total must equal category sum")
    coverage = value.get("coverage_status")
    if not isinstance(coverage, dict):
        errors.append(f"{label}.coverage_status must be an object")
    else:
        for category in CATEGORIES:
            if coverage.get(category) not in OPEN:
                errors.append(f"{label}.coverage_status.{category} must remain open")
    for key in ("native_render", "human_review"):
        gate = value.get(key)
        if not isinstance(gate, dict) or gate.get("status") not in OPEN:
            errors.append(f"{label}.{key}.status must remain open")
    exclusions = value.get("claims_excluded")
    if not isinstance(exclusions, list) or not {"count_approval", "native_render", "human_review"}.issubset(set(exclusions)):
        errors.append(f"{label}.claims_excluded must preserve all open gates")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("summary", type=Path)
    args = parser.parse_args(argv)
    errors = validate_counts(json.loads(args.summary.read_text(encoding="utf-8")))
    if errors:
        print("PLANETARY_DIGEST_COUNT_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PLANETARY_DIGEST_COUNT_VALID_OPEN")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
