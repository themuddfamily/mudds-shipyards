#!/usr/bin/env python3
"""Validate a human-review ledger for planetary hazard landmark digests."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

SCHEMA = "planetary_hazard_landmark_visual_digest_review_v1"
OPEN = {"pending", "not_performed"}
DIGEST = re.compile(r"^[0-9a-fA-F]{64}$")


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def validate_ledger(value: Any, label: str = "ledger") -> list[str]:
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema") != SCHEMA:
        errors.append(f"{label}.schema must be {SCHEMA}")
    for key in ("world_id", "landmark_id", "source_revision"):
        if not _text(value.get(key)):
            errors.append(f"{label}.{key} is required")
    digest = value.get("visual_digest")
    if not isinstance(digest, dict):
        errors.append(f"{label}.visual_digest must be an object")
    else:
        if not _text(digest.get("capture_path")) or not digest["capture_path"].startswith("res://"):
            errors.append(f"{label}.visual_digest.capture_path must be a res:// path")
        if not isinstance(digest.get("sha256"), str) or not DIGEST.fullmatch(digest["sha256"]):
            errors.append(f"{label}.visual_digest.sha256 must be a 64-character digest")
        if digest.get("status") not in OPEN:
            errors.append(f"{label}.visual_digest.status must remain open")
    review = value.get("review")
    if not isinstance(review, dict):
        errors.append(f"{label}.review must be an object")
    else:
        for key in ("silhouette", "route_readability", "hazard_legibility"):
            if not _text(review.get(key)):
                errors.append(f"{label}.review.{key} is required")
        if review.get("status") not in OPEN:
            errors.append(f"{label}.review.status must remain open")
    for key in ("native_render", "human_signoff"):
        gate = value.get(key)
        if not isinstance(gate, dict) or gate.get("status") not in OPEN:
            errors.append(f"{label}.{key}.status must remain open")
    exclusions = value.get("claims_excluded")
    if not isinstance(exclusions, list) or not {"digest_verification", "native_render", "human_signoff"}.issubset(set(exclusions)):
        errors.append(f"{label}.claims_excluded must preserve all open gates")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("ledger", type=Path)
    args = parser.parse_args(argv)
    errors = validate_ledger(json.loads(args.ledger.read_text(encoding="utf-8")))
    if errors:
        print("PLANETARY_HAZARD_DIGEST_REVIEW_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PLANETARY_HAZARD_DIGEST_REVIEW_VALID_OPEN")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
