#!/usr/bin/env python3
"""Validate an index of planetary hazard visual digest summaries."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

SCHEMA = "planetary_hazard_visual_digest_summary_index_v1"
OPEN = {"pending", "not_performed"}


def validate_index(value: Any, label: str = "index") -> list[str]:
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema") != SCHEMA:
        errors.append(f"{label}.schema must be {SCHEMA}")
    for key in ("world_id", "source_revision"):
        if not isinstance(value.get(key), str) or not value[key].strip():
            errors.append(f"{label}.{key} is required")
    regions = value.get("regions")
    if not isinstance(regions, list) or not regions:
        errors.append(f"{label}.regions must contain digest summaries")
        regions = []
    ids: set[str] = set()
    for index, region in enumerate(regions):
        prefix = f"{label}.regions[{index}]"
        if not isinstance(region, dict):
            errors.append(f"{prefix} must be an object")
            continue
        ident = region.get("region_id")
        if not isinstance(ident, str) or not ident.strip() or ident in ids:
            errors.append(f"{prefix}.region_id must be unique")
        ids.add(ident)
        counts = region.get("counts")
        if not isinstance(counts, dict):
            errors.append(f"{prefix}.counts must be an object")
        else:
            for key in ("hazard", "route", "landmark"):
                if not isinstance(counts.get(key), int) or isinstance(counts.get(key), bool) or counts[key] < 1:
                    errors.append(f"{prefix}.counts.{key} must be positive")
        if not isinstance(region.get("summary_status"), str) or region.get("summary_status") not in OPEN:
            errors.append(f"{prefix}.summary_status must remain open")
        if not isinstance(region.get("source_path"), str) or not region["source_path"].startswith("res://"):
            errors.append(f"{prefix}.source_path must be a res:// path")
    aggregate = value.get("aggregate_status")
    if aggregate not in OPEN:
        errors.append(f"{label}.aggregate_status must remain open")
    for key in ("native_render", "human_review"):
        gate = value.get(key)
        if not isinstance(gate, dict) or gate.get("status") not in OPEN:
            errors.append(f"{label}.{key}.status must remain open")
    exclusions = value.get("claims_excluded")
    if not isinstance(exclusions, list) or not {"summary_index", "native_render", "human_review"}.issubset(set(exclusions)):
        errors.append(f"{label}.claims_excluded must preserve all open gates")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("index", type=Path)
    args = parser.parse_args(argv)
    errors = validate_index(json.loads(args.index.read_text(encoding="utf-8")))
    if errors:
        print("PLANETARY_HAZARD_SUMMARY_INDEX_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PLANETARY_HAZARD_SUMMARY_INDEX_VALID_OPEN")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
