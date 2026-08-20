#!/usr/bin/env python3
"""Validate a non-authoritative rollup of the remaining visual review evidence.

This joins capture, source, art-direction, and human-review statuses so a
handoff can be tracked in one place.  It deliberately accepts no approval or
sign-off state: the rollup is evidence coordination, not a release decision.
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

SCHEMA = "evidence_review_rollup_v1"
REQUIRED_AREAS = ("capture", "source", "art", "human_review")
ALLOWED_STATUSES = {"pending", "not_performed", "ready", "incomplete"}
FORBIDDEN_TERMS = {"approved", "pass", "passed", "signed_off", "complete", "released"}


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def validate(path: Path) -> list[str]:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"manifest unreadable: {exc}"]

    errors: list[str] = []
    required = ("schema", "roadmap_items", "source_revision", "reviewer_required", "areas")
    errors.extend(f"manifest missing required key: {key}" for key in required if key not in data)
    if errors:
        return errors
    if data["schema"] != SCHEMA:
        errors.append(f"unsupported schema: {data['schema']!r}")
    if not _text(data["source_revision"]):
        errors.append("source_revision must be non-empty text")
    if not _text(data["reviewer_required"]):
        errors.append("reviewer_required must be non-empty text")
    items = data["roadmap_items"]
    if not isinstance(items, list) or not items or any(not isinstance(item, int) for item in items):
        errors.append("roadmap_items must contain one or more integer item numbers")
    elif len(set(items)) != len(items):
        errors.append("roadmap_items contains duplicate item numbers")

    areas = data["areas"]
    if not isinstance(areas, dict):
        return errors + ["areas must be an object"]
    if set(areas) != set(REQUIRED_AREAS):
        missing = sorted(set(REQUIRED_AREAS) - set(areas))
        extra = sorted(set(areas) - set(REQUIRED_AREAS))
        if missing:
            errors.append("areas missing: " + ", ".join(missing))
        if extra:
            errors.append("areas contain unknown keys: " + ", ".join(extra))
    for area in REQUIRED_AREAS:
        entry = areas.get(area)
        if not isinstance(entry, dict):
            errors.append(f"areas.{area} must be an object")
            continue
        status = entry.get("status")
        if status not in ALLOWED_STATUSES:
            errors.append(f"areas.{area}.status must be one of {sorted(ALLOWED_STATUSES)}")
        for key in ("evidence", "notes"):
            if not _text(entry.get(key)):
                errors.append(f"areas.{area}.{key} must be non-empty text")

    # Reject approval language anywhere in status/decision fields, including
    # future additions to the manifest schema.
    def scan(value: Any, path_text: str = "manifest") -> None:
        if isinstance(value, dict):
            for key, child in value.items():
                if key in {"status", "decision", "outcome", "sign_off"} and isinstance(child, str):
                    if child.lower().replace("-", "_").replace(" ", "_") in FORBIDDEN_TERMS:
                        errors.append(f"{path_text}.{key} cannot claim approval")
                scan(child, f"{path_text}.{key}")
        elif isinstance(value, list):
            for index, child in enumerate(value):
                scan(child, f"{path_text}[{index}]")
    scan(data)
    return errors


def main() -> int:
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    args = parser.parse_args()
    errors = validate(args.manifest.resolve())
    if errors:
        for error in errors:
            print(f"EVIDENCE_REVIEW_ROLLUP_FAILED: {error}")
        return 1
    print(f"EVIDENCE_REVIEW_ROLLUP_READY: {args.manifest} (human sign-off remains external)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
