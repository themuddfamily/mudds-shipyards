#!/usr/bin/env python3
"""Validate v5 planetary hazard visual digest review summaries."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

SCHEMA = "planetary_hazard_digest_review_summary_v5"
OPEN = {"pending", "not_performed"}
KINDS = ("hazard", "landmark", "route")


def validate_summary(value: Any, label: str = "summary") -> list[str]:
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema") != SCHEMA:
        errors.append(f"{label}.schema must be {SCHEMA}")
    for key in ("world_id", "region_id", "source_revision", "reviewer_role"):
        if not isinstance(value.get(key), str) or not value[key].strip():
            errors.append(f"{label}.{key} is required")
    sections = value.get("sections")
    if not isinstance(sections, list) or len(sections) != len(KINDS):
        errors.append(f"{label}.sections must contain hazard, landmark, and route")
        sections = sections if isinstance(sections, list) else []
    seen: set[str] = set()
    for index, section in enumerate(sections):
        prefix = f"{label}.sections[{index}]"
        if not isinstance(section, dict):
            errors.append(f"{prefix} must be an object")
            continue
        kind = section.get("kind")
        if kind not in KINDS or kind in seen:
            errors.append(f"{prefix}.kind must be unique and valid")
        seen.add(kind)
        if not isinstance(section.get("count"), int) or isinstance(section.get("count"), bool) or section["count"] < 1:
            errors.append(f"{prefix}.count must be positive")
        if not isinstance(section.get("evidence_path"), str) or not section["evidence_path"].startswith("res://"):
            errors.append(f"{prefix}.evidence_path must be a res:// path")
        if not isinstance(section.get("review_prompt"), str) or not section["review_prompt"].strip():
            errors.append(f"{prefix}.review_prompt is required")
        if section.get("status") not in OPEN:
            errors.append(f"{prefix}.status must remain open")
    if value.get("summary_status") not in OPEN:
        errors.append(f"{label}.summary_status must remain open")
    for key in ("native_render", "human_signoff"):
        gate = value.get(key)
        if not isinstance(gate, dict) or gate.get("status") not in OPEN:
            errors.append(f"{label}.{key}.status must remain open")
    exclusions = value.get("claims_excluded")
    if not isinstance(exclusions, list) or not {"summary_approval", "native_render", "human_signoff"}.issubset(set(exclusions)):
        errors.append(f"{label}.claims_excluded must preserve all open gates")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("summary", type=Path)
    args = parser.parse_args(argv)
    errors = validate_summary(json.loads(args.summary.read_text(encoding="utf-8")))
    if errors:
        print("PLANETARY_HAZARD_REVIEW_SUMMARY_V5_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PLANETARY_HAZARD_REVIEW_SUMMARY_V5_VALID_OPEN")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
