#!/usr/bin/env python3
"""Validate a planetary visual LOD and streaming evidence rollup.

The rollup is a machine-checkable handoff for later visual/native review.  It
does not run a benchmark, approve art, or claim native GPU performance.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

SCHEMA_VERSION = 1
TIERS = ("near", "mid", "far")


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def validate_rollup(value: Any, label: str = "rollup") -> list[str]:
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    for key in ("world_id", "source_revision"):
        if not _text(value.get(key)):
            errors.append(f"{label}.{key} is required")
    tiers = value.get("lod_tiers")
    if not isinstance(tiers, list) or len(tiers) != len(TIERS):
        errors.append(f"{label}.lod_tiers must contain near, mid, and far")
        tiers = tiers if isinstance(tiers, list) else []
    seen: set[str] = set()
    previous_max = None
    for index, tier in enumerate(tiers):
        prefix = f"{label}.lod_tiers[{index}]"
        if not isinstance(tier, dict):
            errors.append(f"{prefix} must be an object")
            continue
        tier_id = tier.get("id")
        if tier_id not in TIERS or tier_id in seen:
            errors.append(f"{prefix}.id must be a unique near/mid/far value")
        seen.add(tier_id)
        distance = tier.get("distance_m")
        if not isinstance(distance, dict):
            errors.append(f"{prefix}.distance_m must be an object")
        else:
            minimum, maximum = distance.get("min"), distance.get("max")
            if not isinstance(minimum, (int, float)) or isinstance(minimum, bool) or minimum < 0:
                errors.append(f"{prefix}.distance_m.min must be non-negative")
            if not isinstance(maximum, (int, float)) or isinstance(maximum, bool) or maximum <= 0:
                errors.append(f"{prefix}.distance_m.max must be positive")
            if isinstance(minimum, (int, float)) and isinstance(maximum, (int, float)) and minimum >= maximum:
                errors.append(f"{prefix}.distance_m.min must be less than max")
            if previous_max is not None and isinstance(minimum, (int, float)) and minimum < previous_max:
                errors.append(f"{prefix}.distance_m overlaps preceding tier")
            if isinstance(maximum, (int, float)):
                previous_max = maximum
        if not _text(tier.get("capture_id")):
            errors.append(f"{prefix}.capture_id is required")
        if tier.get("human_review_status") not in {"pending", "not_performed"}:
            errors.append(f"{prefix}.human_review_status must remain pending or not_performed")
        budget = tier.get("triangle_budget")
        if not isinstance(budget, int) or isinstance(budget, bool) or budget <= 0:
            errors.append(f"{prefix}.triangle_budget must be positive")

    streaming = value.get("streaming")
    if not isinstance(streaming, dict):
        errors.append(f"{label}.streaming must be an object")
    else:
        for key in ("resident_tiles", "resident_bytes", "max_resident_tiles", "max_resident_bytes"):
            if not isinstance(streaming.get(key), int) or isinstance(streaming.get(key), bool) or streaming.get(key) < 0:
                errors.append(f"{label}.streaming.{key} must be a non-negative integer")
        for actual, ceiling in (("resident_tiles", "max_resident_tiles"), ("resident_bytes", "max_resident_bytes")):
            if isinstance(streaming.get(actual), int) and isinstance(streaming.get(ceiling), int) and streaming[actual] > streaming[ceiling]:
                errors.append(f"{label}.streaming.{actual} exceeds ceiling")
        if streaming.get("metric_status") != "measured" or streaming.get("fabricated_metrics") is not False:
            errors.append(f"{label}.streaming metrics must be measured and non-fabricated")

    native = value.get("native_review")
    if not isinstance(native, dict) or native.get("status") != "NOT_RUN" or native.get("evidence") is not None:
        errors.append(f"{label}.native_review must explicitly remain NOT_RUN without evidence")
    authority = value.get("authority_exclusions")
    if not isinstance(authority, list) or "native_gpu_performance" not in authority or "human_visual_approval" not in authority:
        errors.append(f"{label}.authority_exclusions must retain native and human gates")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("rollup", type=Path)
    args = parser.parse_args(argv)
    errors = validate_rollup(json.loads(args.rollup.read_text(encoding="utf-8")))
    if errors:
        print("PLANETARY_VISUAL_LOD_STREAMING_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PLANETARY_VISUAL_LOD_STREAMING_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
