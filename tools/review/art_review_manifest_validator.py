#!/usr/bin/env python3
"""Validate an art-review handoff without pretending to perform the review.

The manifest proves that a reviewer received the declared captures and rubric.
It intentionally rejects human approval states: visual quality and art
direction remain a manual decision in the target application/GPU context.
"""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

SCHEMA = "art_review_manifest_v1"
FORBIDDEN_HUMAN_STATES = {"pass", "approved", "signed_off", "complete"}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def validate(manifest_path: Path) -> list[str]:
    """Return blocking errors; an empty list means evidence is handoff-ready."""
    try:
        data = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"manifest unreadable: {exc}"]
    errors: list[str] = []
    required = ("schema", "human_review_status", "reviewer_required", "rubric", "captures")
    errors.extend(f"manifest missing required key: {key}" for key in required if key not in data)
    if errors:
        return errors
    if data["schema"] != SCHEMA:
        errors.append(f"unsupported schema: {data['schema']!r}")
    status = data["human_review_status"]
    if status in FORBIDDEN_HUMAN_STATES:
        errors.append("human_review_status cannot claim human approval; this gate only prepares a review")
    if status not in {"pending", "not_performed"}:
        errors.append("human_review_status must be pending or not_performed")
    if not isinstance(data["reviewer_required"], str) or not data["reviewer_required"].strip():
        errors.append("reviewer_required must identify the manual reviewer role")
    rubric = data["rubric"]
    if not isinstance(rubric, list) or not rubric or any(not isinstance(item, str) or not item.strip() for item in rubric):
        errors.append("rubric must contain at least one non-empty review criterion")
    elif len(set(rubric)) != len(rubric):
        errors.append("rubric contains duplicate criteria")
    captures = data["captures"]
    if not isinstance(captures, list) or not captures:
        errors.append("captures must contain at least one frame")
        return errors
    seen: set[str] = set()
    for capture in captures:
        if not isinstance(capture, dict):
            errors.append("each capture must be an object")
            continue
        name = capture.get("path", "")
        if not isinstance(name, str) or not name or name in seen:
            errors.append(f"capture path missing or duplicated: {name!r}")
            continue
        seen.add(name)
        path = manifest_path.parent / name
        if not path.is_file():
            errors.append(f"capture not found: {path}")
            continue
        recorded = capture.get("sha256")
        if not isinstance(recorded, str) or len(recorded) != 64:
            errors.append(f"{name}: sha256 must be a 64-character digest")
        elif sha256(path) != recorded:
            errors.append(f"{name}: SHA-256 does not match manifest")
        if not isinstance(capture.get("viewpoint"), str) or not capture["viewpoint"].strip():
            errors.append(f"{name}: viewpoint is required for manual review")
    return errors


def main() -> int:
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    args = parser.parse_args()
    errors = validate(args.manifest.resolve())
    if errors:
        for error in errors:
            print(f"ART_REVIEW_MANIFEST_FAILED: {error}")
        return 1
    print(f"ART_REVIEW_MANIFEST_READY: {args.manifest} (human review still required)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
