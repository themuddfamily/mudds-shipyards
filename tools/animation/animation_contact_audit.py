#!/usr/bin/env python3
"""Audit animation contact, cycle, and seat-transition evidence.

This is a claim-safety gate around the pilot motion generator's measurements;
it does not turn script-assisted output into animator-authored work or replace
the required human art review.  The manifest records the sole-contact error
window, closed-cycle checks, the two seat-transition joins, and provenance so
those claims cannot silently disappear when the asset is regenerated.
"""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 1
AUTHORING_MODES = {"script_assisted", "animator_authored", "mixed", "unknown"}
REVIEW_STATUSES = {"not_started", "pending", "approved", "rejected"}
TRANSITIONS = {"boarding", "disembark"}


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _finite_number(value: Any) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value)


def _text_array(value: Any) -> bool:
    return isinstance(value, list) and all(_text(item) for item in value)


def validate_audit(value: Any, label: str = "audit") -> list[str]:
    """Return structural and acceptance errors for one contact audit."""
    errors: list[str] = []
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    if value.get("claim_scope") != "animation_contact_boarding_audit":
        errors.append(f"{label}.claim_scope must be animation_contact_boarding_audit")
    for field in ("asset_id", "source_artifact"):
        if not _text(value.get(field)):
            errors.append(f"{label}.{field} must be non-empty")
    mode = value.get("authoring_mode")
    if mode not in AUTHORING_MODES:
        errors.append(f"{label}.authoring_mode must be one of {sorted(AUTHORING_MODES)}")

    provenance = value.get("provenance")
    if not isinstance(provenance, dict):
        errors.append(f"{label}.provenance must be an object")
    else:
        for field in ("generator", "source_rig", "asset_digest"):
            if not _text(provenance.get(field)):
                errors.append(f"{label}.provenance.{field} must be non-empty")
        if provenance.get("byte_reproducible") is not False:
            errors.append(f"{label}.provenance.byte_reproducible must be false unless byte identity is proven")

    clips = value.get("clips")
    if not isinstance(clips, list) or not clips:
        errors.append(f"{label}.clips must be a non-empty array")
    else:
        ids: set[str] = set()
        seen_transitions: set[str] = set()
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
            elif mode == "script_assisted" and clip_mode == "animator_authored":
                errors.append(f"{label}.authoring_mode script_assisted cannot contain animator_authored clips")

            contact = clip.get("sole_contact")
            if not isinstance(contact, dict):
                errors.append(f"{prefix}.sole_contact must be an object")
            else:
                minimum, maximum, tolerance = (contact.get(key) for key in ("min_mm", "max_mm", "tolerance_mm"))
                if not all(_finite_number(item) for item in (minimum, maximum, tolerance)):
                    errors.append(f"{prefix}.sole_contact min_mm, max_mm, and tolerance_mm must be finite numbers")
                else:
                    if minimum > maximum:
                        errors.append(f"{prefix}.sole_contact.min_mm must not exceed max_mm")
                    if tolerance < 0:
                        errors.append(f"{prefix}.sole_contact.tolerance_mm must be non-negative")
                    if abs(minimum) > tolerance or abs(maximum) > tolerance:
                        errors.append(f"{prefix}.sole_contact error exceeds tolerance")
                if not _text(contact.get("evidence")):
                    errors.append(f"{prefix}.sole_contact.evidence must be non-empty")

            cycle = clip.get("cycle")
            if not isinstance(cycle, dict):
                errors.append(f"{prefix}.cycle must be an object")
            else:
                for check in ("closed", "velocity_continuous"):
                    if cycle.get(check) is not True:
                        errors.append(f"{prefix}.cycle.{check} must be true")
                if not _text(cycle.get("evidence")):
                    errors.append(f"{prefix}.cycle.evidence must be non-empty")

            transition = clip.get("seat_transition")
            if transition is not None:
                if not isinstance(transition, dict):
                    errors.append(f"{prefix}.seat_transition must be an object")
                else:
                    kind = transition.get("kind")
                    if kind not in TRANSITIONS:
                        errors.append(f"{prefix}.seat_transition.kind is invalid")
                    else:
                        seen_transitions.add(kind)
                    for check in ("joins_seated_control", "contact_anchor_continuous"):
                        if transition.get(check) is not True:
                            errors.append(f"{prefix}.seat_transition.{check} must be true")
                    if not _text(transition.get("evidence")):
                        errors.append(f"{prefix}.seat_transition.evidence must be non-empty")
        for kind in sorted(TRANSITIONS - seen_transitions):
            errors.append(f"{label}.clips must include a {kind} seat transition")

    review = value.get("human_review")
    if not isinstance(review, dict):
        errors.append(f"{label}.human_review is required; automated checks are not human approval")
    else:
        status = review.get("status")
        if status not in REVIEW_STATUSES:
            errors.append(f"{label}.human_review.status is invalid")
        if not _text(review.get("reviewer")):
            errors.append(f"{label}.human_review.reviewer must identify a person or planned owner")
        if not _text_array(review.get("evidence")):
            errors.append(f"{label}.human_review.evidence must be a text array")
        if status == "approved":
            if not _text(review.get("reviewed_at")):
                errors.append(f"{label}.human_review.reviewed_at is required for approval")
            if not review.get("evidence"):
                errors.append(f"{label}.human_review.evidence is required for approval")
    return errors


def release_ready(value: Any) -> bool:
    """Only approved animator-authored, contact-clean audits are releasable."""
    return not validate_audit(value) and value.get("authoring_mode") == "animator_authored" and value["human_review"].get("status") == "approved"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("audit", type=Path)
    args = parser.parse_args()
    errors = validate_audit(json.loads(args.audit.read_text(encoding="utf-8")))
    if errors:
        print("ANIMATION_CONTACT_AUDIT_INVALID")
        for error in errors:
            print(f"- {error}")
        return 1
    print("ANIMATION_CONTACT_AUDIT_VALID")
    print(f"release_ready={str(release_ready(json.loads(args.audit.read_text(encoding='utf-8')))).lower()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
