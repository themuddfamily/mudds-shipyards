#!/usr/bin/env python3
"""Validate human review metadata for a planetary hazard digest summary."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

SCHEMA = "planetary_hazard_visual_digest_summary_review_v1"
OPEN = {"pending", "not_performed"}


def validate_review(value: Any, label: str = "review") -> list[str]:
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema") != SCHEMA:
        errors.append(f"{label}.schema must be {SCHEMA}")
    for key in ("world_id", "region_id", "source_revision", "reviewer_role"):
        if not isinstance(value.get(key), str) or not value[key].strip():
            errors.append(f"{label}.{key} is required")
    questions = value.get("questions")
    if not isinstance(questions, list) or len(questions) < 3:
        errors.append(f"{label}.questions must cover hazard, route, and landmark")
        questions = []
    ids: set[str] = set()
    for index, question in enumerate(questions):
        prefix = f"{label}.questions[{index}]"
        if not isinstance(question, dict):
            errors.append(f"{prefix} must be an object")
            continue
        ident = question.get("id")
        if not isinstance(ident, str) or not ident.strip() or ident in ids:
            errors.append(f"{prefix}.id must be unique")
        ids.add(ident)
        if question.get("kind") not in {"hazard", "route", "landmark"}:
            errors.append(f"{prefix}.kind is invalid")
        if not isinstance(question.get("prompt"), str) or not question["prompt"].strip():
            errors.append(f"{prefix}.prompt is required")
        if question.get("status") not in OPEN:
            errors.append(f"{prefix}.status must remain open")
    summary = value.get("summary")
    if not isinstance(summary, dict) or summary.get("status") not in OPEN:
        errors.append(f"{label}.summary.status must remain open")
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
    parser.add_argument("review", type=Path)
    args = parser.parse_args(argv)
    errors = validate_review(json.loads(args.review.read_text(encoding="utf-8")))
    if errors:
        print("PLANETARY_HAZARD_SUMMARY_REVIEW_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PLANETARY_HAZARD_SUMMARY_REVIEW_VALID_OPEN")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
