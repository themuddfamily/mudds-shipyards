"""Validate the final visual-review handoff for the five required viewpoints.

This is a provenance and coverage gate; it cannot substitute for a human
review in the running build.
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

SCHEMA = "final_visual_review_bundle_v1"
REQUIRED_VIEWPOINTS = ("station", "cockpit", "combat", "landing", "disembark")
PENDING_STATUSES = {"pending", "not_performed"}
FORBIDDEN_STATUSES = {"approved", "pass", "signed_off", "complete"}


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def validate(path: Path) -> list[str]:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"manifest unreadable: {exc}"]
    errors: list[str] = []
    for key in ("schema", "source_revision", "human_review_status", "reviewer_required", "viewpoints"):
        if key not in data:
            errors.append(f"manifest missing required key: {key}")
    if errors:
        return errors
    if data["schema"] != SCHEMA:
        errors.append(f"unsupported schema: {data['schema']!r}")
    status = data["human_review_status"]
    if status in FORBIDDEN_STATUSES:
        errors.append("human_review_status cannot claim approval")
    if status not in PENDING_STATUSES:
        errors.append("human_review_status must be pending or not_performed")
    for key in ("source_revision", "reviewer_required"):
        if not _text(data[key]):
            errors.append(f"{key} must be non-empty text")
    viewpoints = data["viewpoints"]
    if not isinstance(viewpoints, list):
        return errors + ["viewpoints must be a list"]
    seen: set[str] = set()
    for index, item in enumerate(viewpoints):
        prefix = f"viewpoint[{index}]"
        if not isinstance(item, dict):
            errors.append(f"{prefix} must be an object")
            continue
        ident = item.get("id")
        if ident not in REQUIRED_VIEWPOINTS:
            errors.append(f"{prefix}: id must be one of {', '.join(REQUIRED_VIEWPOINTS)}")
        elif ident in seen:
            errors.append(f"{prefix}: duplicate id {ident!r}")
        else:
            seen.add(ident)
        for key in ("capture", "acceptance", "notes"):
            if not _text(item.get(key)):
                errors.append(f"{prefix}: {key} must be non-empty text")
        if item.get("review_status") not in PENDING_STATUSES:
            errors.append(f"{prefix}: review_status must be pending or not_performed")
    missing = sorted(set(REQUIRED_VIEWPOINTS) - seen)
    if missing:
        errors.append("required viewpoints missing: " + ", ".join(missing))
    return errors


def main() -> int:
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    args = parser.parse_args()
    errors = validate(args.manifest.resolve())
    if errors:
        for error in errors:
            print(f"FINAL_VISUAL_REVIEW_BUNDLE_FAILED: {error}")
        return 1
    print(f"FINAL_VISUAL_REVIEW_BUNDLE_READY: {args.manifest} (human review remains required)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
