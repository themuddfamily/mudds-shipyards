#!/usr/bin/env python3
"""Validate the caption fallback service state-transition evidence ledger.

This ledger records the bounded presentation-service transitions that surround
caption fallback delivery.  It does not run the service, play audio, render
the presenter, or claim human accessibility review.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

SCHEMA = "accessibility_caption_fallback_state_transition_evidence_v1"
OPEN_STATUSES = {"pending", "not_performed", "in_progress", "failed"}
ITEM_STATUSES = {"planned", "pending", "observed", "issue"}
EVIDENCE_KINDS = {"log", "video", "image", "report"}
SHA = re.compile(r"^[0-9a-f]{40,64}$")
SERVICE_STATES = (
    "idle",
    "presenting",
    "presenting_with_pending",
    "hidden_presenting",
    "hidden_presenting_with_pending",
)
EVENTS = (
    "enqueue_first",
    "enqueue_while_active",
    "advance_partial",
    "advance_expiry_idle",
    "advance_expiry_promotes",
    "set_flags_disable",
    "set_flags_enable",
    "duplicate_enqueue",
    "overflow_reject",
    "overflow_replace",
    "reset",
)
TRANSITIONS = (
    ("idle", "enqueue_first", "presenting", "presenting", True),
    ("presenting", "enqueue_while_active", "presenting_with_pending", "queued", True),
    ("presenting", "advance_partial", "presenting", "advanced", True),
    ("presenting", "advance_expiry_idle", "idle", "expired", True),
    ("presenting_with_pending", "advance_expiry_promotes", "presenting", "expired", True),
    ("presenting", "set_flags_disable", "hidden_presenting", "presentation_flags_changed", True),
    ("presenting_with_pending", "set_flags_disable", "hidden_presenting_with_pending", "presentation_flags_changed", True),
    ("hidden_presenting", "set_flags_enable", "presenting", "presentation_flags_changed", True),
    ("hidden_presenting_with_pending", "set_flags_enable", "presenting_with_pending", "presentation_flags_changed", True),
    ("presenting", "duplicate_enqueue", "presenting", "duplicate_event_id", True),
    ("presenting_with_pending", "overflow_reject", "presenting_with_pending", "queue_full", True),
    ("presenting_with_pending", "overflow_replace", "presenting_with_pending", "replaced_lower_priority", True),
    ("presenting", "reset", "idle", "reset", False),
    ("presenting_with_pending", "reset", "idle", "reset", False),
    ("hidden_presenting", "reset", "idle", "reset", False),
    ("hidden_presenting_with_pending", "reset", "idle", "reset", False),
)
REQUIRED_CASES = (
    "first_enqueue_presents",
    "active_enqueue_queues",
    "partial_advance_preserves_active",
    "expiry_reaches_idle",
    "expiry_promotes_pending",
    "disabled_flags_hide_without_pause",
    "duplicate_and_overflow_rejections_preserve_state",
    "reset_clears_queue_and_replay_ledger",
)
LIMITS = {
    "maximum_stored_captions": 8,
    "maximum_dedupe_ids": 1024,
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


def _validate_transitions(value: Any) -> list[str]:
    errors: list[str] = []
    if not isinstance(value, list):
        return ["transitions must contain exactly sixteen ordered service transitions"]
    if len(value) != len(TRANSITIONS):
        errors.append("transitions must contain exactly sixteen ordered service transitions")
    actual: list[tuple[Any, Any, Any, Any, Any]] = []
    for index, transition in enumerate(value):
        prefix = f"transitions[{index}]"
        if not isinstance(transition, dict):
            errors.append(f"{prefix} must be an object")
            continue
        source, event, target, reason, preserves_queue = (transition.get(key) for key in ("source", "event", "target", "reason", "preserves_queue"))
        actual.append((source, event, target, reason, preserves_queue))
        if not isinstance(source, str) or source not in SERVICE_STATES:
            errors.append(f"{prefix}.source must be a frozen service state")
        if not isinstance(event, str) or event not in EVENTS:
            errors.append(f"{prefix}.event must be a frozen transition event")
        if not isinstance(target, str) or target not in SERVICE_STATES:
            errors.append(f"{prefix}.target must be a frozen service state")
        if not _text(reason):
            errors.append(f"{prefix}.reason must be non-empty text")
        if not isinstance(preserves_queue, bool):
            errors.append(f"{prefix}.preserves_queue must be boolean")
    if tuple(actual) != TRANSITIONS:
        errors.append("transitions must exactly match the frozen service transition order")
    return errors


def _validate_cases(value: Any) -> list[str]:
    errors: list[str] = []
    if not isinstance(value, list):
        return ["cases must contain exactly eight service transition cases"]
    if len(value) != len(REQUIRED_CASES):
        errors.append("cases must contain exactly eight service transition cases")
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
        for key in ("transition_ids", "expected", "source_test"):
            if not _text(case.get(key)):
                errors.append(f"{prefix}.{key} must be non-empty text")
        status = case.get("status")
        if not isinstance(status, str) or status not in ITEM_STATUSES:
            errors.append(f"{prefix}.status must remain planned, pending, observed, or issue")
        _references(case.get("evidence"), f"{prefix}.evidence", errors, allow_none=isinstance(status, str) and status in {"planned", "pending"})
    if len(ids) != len(set(ids)):
        errors.append("cases.id values must be unique")
    if tuple(ids) != REQUIRED_CASES:
        errors.append("cases must exactly match the frozen service transition order")
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
    if value.get("states") != list(SERVICE_STATES):
        errors.append("states must exactly match the frozen service states")
    if value.get("events") != list(EVENTS):
        errors.append("events must exactly match the frozen transition events")
    if value.get("limits") != LIMITS:
        errors.append("limits must exactly match the frozen service bounds")
    if value.get("disabled_caption_time_continues") is not True:
        errors.append("disabled_caption_time_continues must be true")
    if value.get("reset_clears_queue_and_ledger") is not True:
        errors.append("reset_clears_queue_and_ledger must be true")
    errors.extend(_validate_transitions(value.get("transitions")))
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
        print("ACCESSIBILITY_CAPTION_STATE_TRANSITION_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("ACCESSIBILITY_CAPTION_STATE_TRANSITION_READY: human review remains open")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
