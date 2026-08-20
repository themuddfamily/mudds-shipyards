#!/usr/bin/env python3
"""Fail-closed validator for the human end-to-end playthrough route.

This is an evidence checklist, not an automated substitute for a human run.
"""
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

REQUIRED_ROUTE = (
    "walking", "boarding", "flight", "combat", "landing", "activities",
    "settings", "save_reentry", "teardown",
)
SEVERITIES = {"P0", "P1", "P2", "P3"}
STATUSES = {"pending", "pass", "fail"}
SHA = re.compile(r"^[0-9a-f]{40,64}$")


def validate(record: Any) -> list[str]:
    errors: list[str] = []
    if not isinstance(record, dict):
        return ["manifest must be an object"]
    if record.get("schema_version") != 1:
        errors.append("schema_version must be 1")
    if record.get("manifest_kind") != "human_playthrough_route":
        errors.append("manifest_kind must be human_playthrough_route")
    status = record.get("human_run_status")
    if status not in STATUSES:
        errors.append("human_run_status must be pending, pass, or fail")
    route = record.get("route")
    if not isinstance(route, list) or not route:
        errors.append("route must be a non-empty list")
        route = []
    seen: set[str] = set()
    for index, step in enumerate(route):
        label = f"route[{index}]"
        if not isinstance(step, dict):
            errors.append(f"{label} must be an object")
            continue
        step_id = step.get("id")
        if not isinstance(step_id, str) or not step_id.strip() or step_id in seen:
            errors.append(f"{label}.id must be unique non-empty text")
        else:
            seen.add(step_id)
        if step.get("result") not in STATUSES:
            errors.append(f"{label}.result must be pending, pass, or fail")
        if not isinstance(step.get("observations"), list) or not step["observations"]:
            errors.append(f"{label}.observations must be a non-empty list")
    missing = sorted(set(REQUIRED_ROUTE) - seen)
    if missing:
        errors.append("route missing required steps: " + ", ".join(missing))
    source = record.get("source_commit")
    if source is not None and (not isinstance(source, str) or not SHA.fullmatch(source)):
        errors.append("source_commit must be null or a lowercase commit SHA")
    defects = record.get("defects", [])
    if not isinstance(defects, list):
        errors.append("defects must be a list")
        defects = []
    for index, defect in enumerate(defects):
        label = f"defects[{index}]"
        if not isinstance(defect, dict):
            errors.append(f"{label} must be an object")
            continue
        if defect.get("severity") not in SEVERITIES:
            errors.append(f"{label}.severity must be P0-P3")
        for field in ("route_step", "location", "state", "source_commit"):
            if not isinstance(defect.get(field), str) or not defect[field].strip():
                errors.append(f"{label}.{field} is required")
        if not isinstance(defect.get("visual_evidence"), bool):
            errors.append(f"{label}.visual_evidence must be boolean")
    if status == "pass":
        if not SHA.fullmatch(source or ""):
            errors.append("pass requires source_commit")
        if any(step.get("result") != "pass" for step in route if isinstance(step, dict)):
            errors.append("pass requires every route step to pass")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("manifest", type=Path)
    args = parser.parse_args()
    try:
        errors = validate(json.loads(args.manifest.read_text(encoding="utf-8")))
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"PLAYTHROUGH_ROUTE_INVALID: {exc}")
        return 1
    if errors:
        print("PLAYTHROUGH_ROUTE_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print(f"PLAYTHROUGH_ROUTE_VALID: {args.manifest}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
