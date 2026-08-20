#!/usr/bin/env python3
"""Validate provenance claims for character and boarding animation.

This is an evidence gate, not an animation-quality oracle.  In particular,
key counts, generator output, and automated pose checks cannot be presented as
animator-authored work or as human art approval.  The manifest therefore keeps
the authoring mode explicit and requires a human-review record even while a
clip is still pending review.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 1
AUTHORING_MODES = {"script_assisted", "animator_authored", "mixed", "unknown"}
REVIEW_STATUSES = {"not_started", "pending", "approved", "rejected"}
CHECK_STATUSES = {"pass", "fail", "not_checked"}
QUALITY_CHECKS = ("foot_contacts", "pose_continuity", "transition_continuity", "semantic_orientation")


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _non_negative_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value >= 0


def _positive_number(value: Any) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool) and value > 0


def validate_manifest(value: Any, label: str = "manifest") -> list[str]:
    """Return structural and claim-safety errors for an animation manifest."""
    errors: list[str] = []
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    if value.get("claim_scope") != "animation_provenance_and_quality_audit":
        errors.append(f"{label}.claim_scope must be animation_provenance_and_quality_audit")
    for field in ("asset_id", "source_artifact"):
        if not _text(value.get(field)):
            errors.append(f"{label}.{field} must be non-empty")

    mode = value.get("authoring_mode")
    if mode not in AUTHORING_MODES:
        errors.append(f"{label}.authoring_mode must be one of {sorted(AUTHORING_MODES)}")

    clips = value.get("clips")
    if not isinstance(clips, list) or not clips:
        errors.append(f"{label}.clips must be a non-empty array")
    else:
        ids: set[str] = set()
        clip_modes: set[str] = set()
        for index, clip in enumerate(clips):
            prefix = f"{label}.clips[{index}]"
            if not isinstance(clip, dict):
                errors.append(f"{prefix} must be an object")
                continue
            clip_id = clip.get("id")
            if not _text(clip_id):
                errors.append(f"{prefix}.id must be non-empty")
            elif clip_id in ids:
                errors.append(f"{prefix}.id must be unique")
            else:
                ids.add(clip_id)
            clip_mode = clip.get("authoring_mode")
            if clip_mode not in AUTHORING_MODES:
                errors.append(f"{prefix}.authoring_mode is invalid")
            else:
                clip_modes.add(clip_mode)
            if not _positive_number(clip.get("duration_seconds")):
                errors.append(f"{prefix}.duration_seconds must be positive")
            if not _positive_number(clip.get("sample_rate_hz")):
                errors.append(f"{prefix}.sample_rate_hz must be positive")
            if not _non_negative_int(clip.get("keyframe_count")) or clip.get("keyframe_count") < 1:
                errors.append(f"{prefix}.keyframe_count must be a positive integer")

        if mode == "script_assisted" and "animator_authored" in clip_modes:
            errors.append(f"{label}.authoring_mode script_assisted cannot contain animator_authored clips")
        if mode == "animator_authored" and clip_modes - {"animator_authored"}:
            errors.append(f"{label}.authoring_mode animator_authored cannot contain non-animator clips")
        if mode == "mixed" and len(clip_modes) < 2:
            errors.append(f"{label}.authoring_mode mixed must identify at least two clip authoring modes")

    audit = value.get("quality_audit")
    if not isinstance(audit, dict):
        errors.append(f"{label}.quality_audit must be an object")
    else:
        if not _text(audit.get("auditor")):
            errors.append(f"{label}.quality_audit.auditor must identify the audit source")
        checks = audit.get("checks")
        if not isinstance(checks, dict):
            errors.append(f"{label}.quality_audit.checks must be an object")
        else:
            for check in QUALITY_CHECKS:
                row = checks.get(check)
                if not isinstance(row, dict):
                    errors.append(f"{label}.quality_audit.checks.{check} must be an object")
                    continue
                if row.get("status") not in CHECK_STATUSES:
                    errors.append(f"{label}.quality_audit.checks.{check}.status is invalid")
                if not _text(row.get("evidence")):
                    errors.append(f"{label}.quality_audit.checks.{check}.evidence must be non-empty")
        limitations = audit.get("limitations")
        if not isinstance(limitations, list) or not all(_text(item) for item in limitations):
            errors.append(f"{label}.quality_audit.limitations must be a non-empty text array")
        elif mode in {"script_assisted", "mixed", "unknown"} and not limitations:
            errors.append(f"{label}.quality_audit.limitations must describe non-animator provenance")

    review = value.get("human_review")
    if not isinstance(review, dict):
        errors.append(f"{label}.human_review is required; automated checks are not human approval")
    else:
        status = review.get("status")
        if status not in REVIEW_STATUSES:
            errors.append(f"{label}.human_review.status is invalid")
        if not _text(review.get("reviewer")):
            errors.append(f"{label}.human_review.reviewer must identify a person or planned owner")
        evidence = review.get("evidence")
        if not isinstance(evidence, list) or not all(_text(item) for item in evidence):
            errors.append(f"{label}.human_review.evidence must be a text array")
        if status == "approved":
            if not _text(review.get("reviewed_at")):
                errors.append(f"{label}.human_review.reviewed_at is required for approval")
            if not isinstance(evidence, list) or not evidence:
                errors.append(f"{label}.human_review.evidence is required for approval")

    return errors


def release_ready(value: Any) -> bool:
    """Return true only for animator-authored content with explicit approval."""
    if validate_manifest(value):
        return False
    return value.get("authoring_mode") == "animator_authored" and value["human_review"].get("status") == "approved"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    args = parser.parse_args()
    value = json.loads(args.manifest.read_text(encoding="utf-8"))
    errors = validate_manifest(value)
    if errors:
        print("ANIMATION_PROVENANCE_INVALID")
        for error in errors:
            print(f"- {error}")
        return 1
    print("ANIMATION_PROVENANCE_VALID")
    print(f"release_ready={str(release_ready(value)).lower()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
