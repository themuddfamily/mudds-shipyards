#!/usr/bin/env python3
"""Validate generation and authority stale-guard evidence for captions.

The validator freezes the guard inputs, acceptance predicate, and forbidden
authority claims at the caption handoff boundary.  It does not add runtime
logic, enqueue content, play audio, render UI, or claim human accessibility
review.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

SCHEMA = "accessibility_caption_generation_authority_stale_guard_evidence_v1"
OPEN_STATUSES = {"pending", "not_performed", "in_progress", "failed"}
ITEM_STATUSES = {"planned", "pending", "observed", "issue"}
EVIDENCE_KINDS = {"log", "video", "image", "report"}
SHA = re.compile(r"^[0-9a-f]{40,64}$")
GUARD_INPUTS = ("generation", "revision", "presentation_only")
CHECK_IDS = (
    "current_generation_presentation_accepts",
    "stale_generation_rejects",
    "future_generation_rejects",
    "stale_revision_rejects",
    "non_presentation_authority_rejects",
    "reset_generation_invalidates_old_payload",
    "detached_snapshot_cannot_gain_authority",
)
CHECK_RULES = {
    "current_generation_presentation_accepts": {"result": "accepted", "reason": "current_generation", "mutation": "presentation_only"},
    "stale_generation_rejects": {"result": "rejected", "reason": "stale_generation", "mutation": "none"},
    "future_generation_rejects": {"result": "rejected", "reason": "future_generation", "mutation": "none"},
    "stale_revision_rejects": {"result": "rejected", "reason": "stale_revision", "mutation": "none"},
    "non_presentation_authority_rejects": {"result": "rejected", "reason": "authority_boundary", "mutation": "none"},
    "reset_generation_invalidates_old_payload": {"result": "rejected", "reason": "stale_generation", "mutation": "none"},
    "detached_snapshot_cannot_gain_authority": {"result": "rejected", "reason": "authority_boundary", "mutation": "none"},
}
REQUIRED_CASES = CHECK_IDS
LIMITS = {"minimum_generation": 0, "minimum_revision": 0, "generation_step_after_reset": 1, "maximum_safe_sequence": 9007199254740991}


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _sha(value: Any) -> bool:
    return isinstance(value, str) and bool(SHA.fullmatch(value))


def _references(value: Any, prefix: str, errors: list[str], *, allow_none: bool) -> None:
    if value is None and allow_none:
        return
    if not isinstance(value, list) or not value:
        errors.append(f"{prefix} must be null while pending or a non-empty evidence list")
        return
    seen: set[tuple[str, str]] = set()
    for index, reference in enumerate(value):
        label = f"{prefix}[{index}]"
        if not isinstance(reference, dict):
            errors.append(f"{label} must be an object")
            continue
        kind = reference.get("kind")
        if not isinstance(kind, str) or kind not in EVIDENCE_KINDS:
            errors.append(f"{label}.kind must be log, video, image, or report")
        path, digest = reference.get("path"), reference.get("sha256")
        if not _text(path):
            errors.append(f"{label}.path must be non-empty text")
        if not _sha(digest):
            errors.append(f"{label}.sha256 must be a lowercase digest")
        if isinstance(path, str) and isinstance(digest, str):
            identity = (path, digest)
            if identity in seen:
                errors.append(f"{label} duplicates an earlier reference")
            seen.add(identity)


def _validate_checks(value: Any) -> list[str]:
    errors: list[str] = []
    if not isinstance(value, list):
        return ["checks must contain exactly seven ordered generation/authority checks"]
    if len(value) != len(CHECK_IDS):
        errors.append("checks must contain exactly seven ordered generation/authority checks")
    ids: list[str] = []
    for index, check in enumerate(value):
        prefix = f"checks[{index}]"
        if not isinstance(check, dict):
            errors.append(f"{prefix} must be an object")
            continue
        check_id = check.get("id")
        if check_id not in CHECK_IDS:
            errors.append(f"{prefix}.id must be one of the frozen generation/authority checks")
        else:
            ids.append(check_id)
            expected = CHECK_RULES[check_id]
            for key in ("result", "reason", "mutation"):
                if check.get(f"expected_{key}") != expected[key]:
                    errors.append(f"{prefix}.expected_{key} must match its generation/authority check")
        if not _text(check.get("expected_behavior")):
            errors.append(f"{prefix}.expected_behavior must be non-empty text")
        status = check.get("status")
        if not isinstance(status, str) or status not in ITEM_STATUSES:
            errors.append(f"{prefix}.status must remain planned, pending, observed, or issue")
        _references(check.get("evidence"), f"{prefix}.evidence", errors, allow_none=isinstance(status, str) and status in {"planned", "pending"})
    if len(ids) != len(set(ids)):
        errors.append("checks.id values must be unique")
    if tuple(ids) != CHECK_IDS:
        errors.append("checks must exactly match the frozen generation/authority order")
    return errors


def validate_ledger(value: Any) -> list[str]:
    """Return blocking errors; empty means ready for the still-open review gate."""
    if not isinstance(value, dict):
        return ["ledger must be an object"]
    errors: list[str] = []
    if value.get("schema") != SCHEMA:
        errors.append(f"schema must be {SCHEMA}")
    human_review_status = value.get("human_review_status")
    if not isinstance(human_review_status, str) or human_review_status not in OPEN_STATUSES:
        errors.append("human_review_status must remain pending, not_performed, in_progress, or failed")
    native_render_status = value.get("native_render_status")
    if not isinstance(native_render_status, str) or native_render_status not in {"not_run", "planned", "blocked"}:
        errors.append("native_render_status must remain not_run, planned, or blocked")
    for key in ("source_revision", "service_source", "boundary_source", "reviewer_required", "open_gate_reason"):
        if not _text(value.get(key)):
            errors.append(f"{key} must be non-empty text")
    for key, expected in (
        ("human_review_performed", False),
        ("native_render_performed", False),
        ("presentation_only", True),
        ("audio_authority", False),
        ("audio_playback", False),
        ("caption_queue_authority", False),
        ("settings_authority", False),
        ("gameplay_authority", False),
        ("network_authority", False),
        ("stale_payload_mutation", False),
    ):
        if value.get(key) is not expected:
            errors.append(f"{key} must be {str(expected).lower()}")
    if value.get("service_id") != "caption-presentation-service":
        errors.append("service_id must identify caption-presentation-service")
    if value.get("guard_inputs") != list(GUARD_INPUTS):
        errors.append("guard_inputs must exactly match generation, revision, and presentation_only")
    if value.get("acceptance_predicate") != "generation_current_and_revision_current_and_presentation_only":
        errors.append("acceptance_predicate must require current generation, revision, and presentation-only authority")
    if value.get("stale_predicate") != "generation_or_revision_mismatch":
        errors.append("stale_predicate must be generation_or_revision_mismatch")
    if value.get("authority_rejection_reason") != "authority_boundary":
        errors.append("authority_rejection_reason must be authority_boundary")
    if value.get("reset_generation_step") != 1:
        errors.append("reset_generation_step must be 1")
    if value.get("limits") != LIMITS:
        errors.append("limits must exactly match the frozen generation/authority bounds")
    errors.extend(_validate_checks(value.get("checks")))
    return errors


def validate(path: str | Path) -> list[str]:
    try:
        value = json.loads(Path(path).read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"ledger unreadable: {exc}"]
    return validate_ledger(value)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("ledger", type=Path)
    args = parser.parse_args(argv)
    errors = validate(args.ledger)
    if errors:
        print("ACCESSIBILITY_CAPTION_GENERATION_AUTHORITY_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("ACCESSIBILITY_CAPTION_GENERATION_AUTHORITY_READY: human review remains open")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
