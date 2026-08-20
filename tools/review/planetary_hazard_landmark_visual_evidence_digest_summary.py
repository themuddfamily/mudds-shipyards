#!/usr/bin/env python3
"""Validate aggregate summary metadata for planetary visual evidence."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

SCHEMA = "planetary_hazard_landmark_visual_digest_summary_v1"
OPEN = {"pending", "not_performed"}


def validate_summary(value: Any, label: str = "summary") -> list[str]:
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
    else:
        for key in ("hazard", "landmark", "route", "total"):
            item = counts.get(key)
            if not isinstance(item, int) or isinstance(item, bool) or item < 0:
                errors.append(f"{label}.counts.{key} must be a non-negative integer")
        if all(isinstance(counts.get(key), int) and not isinstance(counts.get(key), bool) for key in ("hazard", "landmark", "route", "total")) and counts["total"] != counts["hazard"] + counts["landmark"] + counts["route"]:
            errors.append(f"{label}.counts.total must equal category sum")
        if isinstance(counts.get("total"), int) and counts["total"] < 3:
            errors.append(f"{label}.counts.total must cover the three evidence categories")
    coverage = value.get("coverage")
    if not isinstance(coverage, list) or set(coverage) != {"hazard", "landmark", "route"}:
        errors.append(f"{label}.coverage must list hazard, landmark, and route exactly")
    digest = value.get("summary_digest")
    if not isinstance(digest, dict) or not isinstance(digest.get("algorithm"), str) or digest.get("algorithm") != "sha256" or not isinstance(digest.get("status"), str) or digest.get("status") not in OPEN:
        errors.append(f"{label}.summary_digest must declare sha256 with an open status")
    for key in ("native_render", "human_review"):
        gate = value.get(key)
        if not isinstance(gate, dict) or gate.get("status") not in OPEN:
            errors.append(f"{label}.{key}.status must remain open")
    exclusions = value.get("claims_excluded")
    if not isinstance(exclusions, list) or not {"summary_approval", "native_render", "human_review"}.issubset(set(exclusions)):
        errors.append(f"{label}.claims_excluded must preserve all open gates")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("summary", type=Path)
    args = parser.parse_args(argv)
    errors = validate_summary(json.loads(args.summary.read_text(encoding="utf-8")))
    if errors:
        print("PLANETARY_VISUAL_DIGEST_SUMMARY_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PLANETARY_VISUAL_DIGEST_SUMMARY_VALID_OPEN")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
