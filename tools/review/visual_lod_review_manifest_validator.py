#!/usr/bin/env python3
"""Validate a visual LOD transition review handoff.

The manifest records enough evidence for a reviewer to inspect near, mid and
far transitions.  It is deliberately not an image-quality verdict: distance
bands, paired capture provenance and the silhouette/readability rubric are
machine-checkable, while the actual visual decision remains human work.
"""

from __future__ import annotations

import hashlib
import json
import re
from pathlib import Path
from typing import Any

SCHEMA = "visual_lod_review_manifest_v1"
TIER_IDS = ("near", "mid", "far")
PENDING_STATUSES = {"pending", "not_performed"}
FORBIDDEN_STATUSES = {"approved", "pass", "signed_off", "complete"}
SHA256 = re.compile(r"^[0-9a-fA-F]{64}$")


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def _capture(errors: list[str], manifest_path: Path, value: Any, label: str) -> None:
    if not isinstance(value, dict):
        errors.append(f"{label} must be an object")
        return
    path_name = value.get("path")
    if not _text(path_name):
        errors.append(f"{label}.path is required")
    else:
        path = manifest_path.parent / path_name
        if not path.is_file():
            errors.append(f"{label}: capture not found: {path}")
        else:
            recorded = value.get("sha256")
            if not isinstance(recorded, str) or not SHA256.fullmatch(recorded):
                errors.append(f"{label}.sha256 must be a 64-character digest")
            elif _sha256(path) != recorded:
                errors.append(f"{label}: SHA-256 does not match manifest")
    if not _text(value.get("viewpoint")):
        errors.append(f"{label}.viewpoint is required")


def validate(manifest_path: Path) -> list[str]:
    """Return blocking errors; an empty list means the review is handoff-ready."""
    try:
        data = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"manifest unreadable: {exc}"]

    errors: list[str] = []
    required = ("schema", "source_revision", "human_review_status", "reviewer_required", "rubric", "tiers")
    errors.extend(f"manifest missing required key: {key}" for key in required if key not in data)
    if errors:
        return errors
    if data["schema"] != SCHEMA:
        errors.append(f"unsupported schema: {data['schema']!r}")
    if not _text(data["source_revision"]):
        errors.append("source_revision must be non-empty text")
    status = data["human_review_status"]
    if status in FORBIDDEN_STATUSES:
        errors.append("human_review_status cannot claim human approval")
    if status not in PENDING_STATUSES:
        errors.append("human_review_status must be pending or not_performed")
    if not _text(data["reviewer_required"]):
        errors.append("reviewer_required must identify the manual reviewer role")

    rubric = data["rubric"]
    if not isinstance(rubric, dict):
        errors.append("rubric must be an object")
    else:
        for key in ("silhouette", "readability"):
            values = rubric.get(key)
            if not isinstance(values, list) or not values or any(not _text(item) for item in values):
                errors.append(f"rubric.{key} must contain non-empty criteria")
            elif len(set(values)) != len(values):
                errors.append(f"rubric.{key} contains duplicate criteria")

    tiers = data["tiers"]
    if not isinstance(tiers, list) or len(tiers) != len(TIER_IDS):
        errors.append("tiers must contain exactly near, mid, and far entries")
        tiers = tiers if isinstance(tiers, list) else []
    seen: set[str] = set()
    previous_max = None
    for index, tier in enumerate(tiers):
        label = f"tiers[{index}]"
        if not isinstance(tier, dict):
            errors.append(f"{label} must be an object")
            continue
        ident = tier.get("id")
        if ident not in TIER_IDS:
            errors.append(f"{label}.id must be one of {', '.join(TIER_IDS)}")
        elif ident in seen:
            errors.append(f"{label}: duplicate id {ident!r}")
        else:
            seen.add(ident)
        distance = tier.get("distance_m")
        if not isinstance(distance, dict):
            errors.append(f"{label}.distance_m must be an object")
        else:
            minimum, maximum = distance.get("min"), distance.get("max")
            if not isinstance(minimum, (int, float)) or isinstance(minimum, bool) or minimum < 0:
                errors.append(f"{label}.distance_m.min must be a non-negative number")
            if not isinstance(maximum, (int, float)) or isinstance(maximum, bool) or maximum <= 0:
                errors.append(f"{label}.distance_m.max must be a positive number")
            if isinstance(minimum, (int, float)) and isinstance(maximum, (int, float)) and minimum >= maximum:
                errors.append(f"{label}.distance_m.min must be less than max")
            if (previous_max is not None and isinstance(minimum, (int, float)) and minimum < previous_max):
                errors.append(f"{label}.distance_m overlaps the preceding tier")
            if isinstance(maximum, (int, float)):
                previous_max = maximum
        for key in ("silhouette", "readability", "review_status"):
            if key in ("silhouette", "readability") and not _text(tier.get(key)):
                errors.append(f"{label}.{key} is required")
        if tier.get("review_status") not in PENDING_STATUSES:
            errors.append(f"{label}.review_status must be pending or not_performed")
        _capture(errors, manifest_path, tier.get("before"), f"{label}.before")
        _capture(errors, manifest_path, tier.get("after"), f"{label}.after")
    missing = set(TIER_IDS) - seen
    if missing:
        errors.append("required tiers missing: " + ", ".join(sorted(missing)))
    return errors


def main(argv: list[str] | None = None) -> int:
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    args = parser.parse_args(argv)
    errors = validate(args.manifest.resolve())
    for error in errors:
        print(f"VISUAL_LOD_REVIEW_FAILED: {error}")
    if not errors:
        print("VISUAL_LOD_REVIEW_READY: human visual review still required")
    return int(bool(errors))


if __name__ == "__main__":
    raise SystemExit(main())
