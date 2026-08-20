#!/usr/bin/env python3
"""Validate stale-state safeguards for accessibility caption fallback.

The ledger freezes lifecycle and replay boundaries that keep an old caption or
fallback from leaking across reset, duplicate, disabled, or invalid-time
conditions.  It does not run the service, render UI, play audio, or claim
human accessibility review.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

SCHEMA = "accessibility_caption_fallback_stale_state_evidence_v1"
OPEN_STATUSES = {"pending", "not_performed", "in_progress", "failed"}
ITEM_STATUSES = {"planned", "pending", "observed", "issue"}
EVIDENCE_KINDS = {"log", "video", "image", "report"}
SHA = re.compile(r"^[0-9a-f]{40,64}$")
FALLBACK_TEXT = "[inaudible]"
STALE_BOUNDARIES = (
    "reset_generation_boundary",
    "duplicate_id_replay_boundary",
    "id_reuse_after_reset",
    "disabled_time_continuity",
    "finite_delta_boundary",
    "detached_snapshot_boundary",
    "fallback_text_stability",
)
BOUNDARY_RULES = {
    "reset_generation_boundary": {"result": "reset", "authority": "service_lifecycle"},
    "duplicate_id_replay_boundary": {"result": "duplicate_event_id", "authority": "service_dedupe"},
    "id_reuse_after_reset": {"result": "accepted_after_reset", "authority": "service_lifecycle"},
    "disabled_time_continuity": {"result": "hidden_but_time_continues", "authority": "presentation_only"},
    "finite_delta_boundary": {"result": "invalid_delta", "authority": "caller_physics"},
    "detached_snapshot_boundary": {"result": "deep_detached_scalar_data", "authority": "snapshot"},
    "fallback_text_stability": {"result": FALLBACK_TEXT, "authority": "accessibility_contract"},
}
REQUIRED_CASES = (
    "reset_drops_old_active_and_pending",
    "duplicate_id_cannot_replay",
    "same_id_is_fresh_after_reset",
    "disabled_captions_do_not_pause_time",
    "invalid_delta_cannot_mutate_state",
    "snapshot_mutation_cannot_mutate_service",
    "inaudible_empty_text_stays_fallback",
)
LIMITS = {
    "maximum_stored_captions": 8,
    "maximum_dedupe_ids": 1024,
    "maximum_safe_sequence": 9007199254740991,
    "time_source": "caller_supplied_physics_delta_only",
}


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


def _validate_boundaries(value: Any) -> list[str]:
    errors: list[str] = []
    if not isinstance(value, list):
        return ["boundaries must contain exactly seven ordered stale-state boundaries"]
    if len(value) != len(STALE_BOUNDARIES):
        errors.append("boundaries must contain exactly seven ordered stale-state boundaries")
    ids: list[str] = []
    for index, boundary in enumerate(value):
        prefix = f"boundaries[{index}]"
        if not isinstance(boundary, dict):
            errors.append(f"{prefix} must be an object")
            continue
        boundary_id = boundary.get("id")
        if boundary_id not in STALE_BOUNDARIES:
            errors.append(f"{prefix}.id must be one of the frozen stale-state boundaries")
        else:
            ids.append(boundary_id)
            expected = BOUNDARY_RULES[boundary_id]
            for key in ("result", "authority"):
                if boundary.get(key) != expected[key]:
                    errors.append(f"{prefix}.{key} must match its stale-state boundary")
        if not _text(boundary.get("expected_behavior")):
            errors.append(f"{prefix}.expected_behavior must be non-empty text")
        status = boundary.get("status")
        if not isinstance(status, str) or status not in ITEM_STATUSES:
            errors.append(f"{prefix}.status must remain planned, pending, observed, or issue")
        _references(boundary.get("evidence"), f"{prefix}.evidence", errors, allow_none=isinstance(status, str) and status in {"planned", "pending"})
    if len(ids) != len(set(ids)):
        errors.append("boundaries.id values must be unique")
    if tuple(ids) != STALE_BOUNDARIES:
        errors.append("boundaries must exactly match the frozen stale-state order")
    return errors


def _validate_cases(value: Any) -> list[str]:
    errors: list[str] = []
    if not isinstance(value, list):
        return ["cases must contain exactly seven stale-state cases"]
    if len(value) != len(REQUIRED_CASES):
        errors.append("cases must contain exactly seven stale-state cases")
    ids: list[str] = []
    for index, case in enumerate(value):
        prefix = f"cases[{index}]"
        if not isinstance(case, dict):
            errors.append(f"{prefix} must be an object")
            continue
        case_id = case.get("id")
        if not _text(case_id):
            errors.append(f"{prefix}.id must be non-empty text")
        else:
            ids.append(case_id)
        for key in ("boundary", "expected", "source_test"):
            if not _text(case.get(key)):
                errors.append(f"{prefix}.{key} must be non-empty text")
        if case.get("boundary") not in STALE_BOUNDARIES:
            errors.append(f"{prefix}.boundary must name a frozen stale-state boundary")
        status = case.get("status")
        if not isinstance(status, str) or status not in ITEM_STATUSES:
            errors.append(f"{prefix}.status must remain planned, pending, observed, or issue")
        _references(case.get("evidence"), f"{prefix}.evidence", errors, allow_none=isinstance(status, str) and status in {"planned", "pending"})
    if len(ids) != len(set(ids)):
        errors.append("cases.id values must be unique")
    if tuple(ids) != REQUIRED_CASES:
        errors.append("cases must exactly match the frozen stale-state order")
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
    for key in ("source_revision", "service_source", "contract_source", "reviewer_required", "open_gate_reason"):
        if not _text(value.get(key)):
            errors.append(f"{key} must be non-empty text")
    for key, expected in (
        ("human_review_performed", False),
        ("native_render_performed", False),
        ("detached_contract_tests_only", True),
        ("presentation_only", True),
        ("audio_authority", False),
        ("caption_queue_authority", False),
        ("settings_authority", False),
        ("gameplay_authority", False),
    ):
        if value.get(key) is not expected:
            errors.append(f"{key} must be {str(expected).lower()}")
    if value.get("service_id") != "caption-presentation-service":
        errors.append("service_id must identify caption-presentation-service")
    if value.get("contract_id") != "caption-accessibility-contract":
        errors.append("contract_id must identify caption-accessibility-contract")
    if value.get("fallback_text") != FALLBACK_TEXT:
        errors.append("fallback_text must be [inaudible]")
    if value.get("limits") != LIMITS:
        errors.append("limits must exactly match the frozen stale-state bounds")
    if value.get("wall_clock_authority") is not False:
        errors.append("wall_clock_authority must be false")
    if value.get("reset_increments_generation") is not True:
        errors.append("reset_increments_generation must be true")
    errors.extend(_validate_boundaries(value.get("boundaries")))
    errors.extend(_validate_cases(value.get("cases")))
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
        print("ACCESSIBILITY_CAPTION_STALE_STATE_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("ACCESSIBILITY_CAPTION_STALE_STATE_READY: human review remains open")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
