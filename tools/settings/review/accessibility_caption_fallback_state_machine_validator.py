#!/usr/bin/env python3
"""Validate the accessibility caption fallback state-machine evidence.

This detached index freezes the contract's rejection, presentation, and
inaudible-text fallback transitions.  It does not enqueue captions, play
audio, render the presenter, or claim human readability review.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

SCHEMA = "accessibility_caption_fallback_state_machine_evidence_v1"
OPEN_STATUSES = {"pending", "not_performed", "in_progress", "failed"}
ITEM_STATUSES = {"planned", "pending", "observed", "issue"}
EVIDENCE_KINDS = {"log", "video", "image", "report"}
SHA = re.compile(r"^[0-9a-f]{40,64}$")
FALLBACK_TEXT = "[inaudible]"
STATES = (
    "input",
    "rejected_invalid",
    "rejected_disabled",
    "rejected_filtered",
    "presenting_text",
    "presenting_fallback",
)
TERMINAL_STATES = ("rejected_invalid", "rejected_disabled", "rejected_filtered", "presenting_text", "presenting_fallback")
EVENTS = (
    "invalid_cue",
    "captions_disabled",
    "verbosity_filtered",
    "audible_text",
    "inaudible_text",
    "inaudible_empty_text",
)
TRANSITIONS = (
    ("input", "invalid_cue", "rejected_invalid", "invalid_cue"),
    ("input", "captions_disabled", "rejected_disabled", "captions_disabled"),
    ("input", "verbosity_filtered", "rejected_filtered", "verbosity_filtered"),
    ("input", "audible_text", "presenting_text", "present"),
    ("input", "inaudible_text", "presenting_text", "present"),
    ("input", "inaudible_empty_text", "presenting_fallback", "present_inaudible_fallback"),
)
REQUIRED_CASES = (
    "invalid_cue_rejected",
    "captions_disabled_rejected",
    "verbosity_filtered_rejected",
    "audible_text_presented",
    "inaudible_text_presented",
    "inaudible_empty_fallback",
)


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


def _validate_states(value: Any) -> list[str]:
    errors: list[str] = []
    if not isinstance(value, list):
        return ["states must contain exactly six ordered fallback states"]
    if len(value) != len(STATES):
        errors.append("states must contain exactly six ordered fallback states")
    ids: list[str] = []
    for index, state in enumerate(value):
        prefix = f"states[{index}]"
        if not isinstance(state, dict):
            errors.append(f"{prefix} must be an object")
            continue
        state_id = state.get("id")
        if state_id not in STATES:
            errors.append(f"{prefix}.id must be one of the frozen fallback states")
        else:
            ids.append(state_id)
            expected_terminal = state_id in TERMINAL_STATES
            if state.get("terminal") is not expected_terminal:
                errors.append(f"{prefix}.terminal must match its fallback state")
        if not _text(state.get("description")):
            errors.append(f"{prefix}.description must be non-empty text")
    if len(ids) != len(set(ids)):
        errors.append("states.id values must be unique")
    if tuple(ids) != STATES:
        errors.append("states must exactly match the frozen fallback-state order")
    return errors


def _validate_transitions(value: Any) -> list[str]:
    errors: list[str] = []
    if not isinstance(value, list):
        return ["transitions must contain exactly six ordered fallback transitions"]
    if len(value) != len(TRANSITIONS):
        errors.append("transitions must contain exactly six ordered fallback transitions")
    actual: list[tuple[Any, Any, Any, Any]] = []
    for index, transition in enumerate(value):
        prefix = f"transitions[{index}]"
        if not isinstance(transition, dict):
            errors.append(f"{prefix} must be an object")
            continue
        source, event, target, reason = (transition.get(key) for key in ("source", "event", "target", "reason"))
        actual.append((source, event, target, reason))
        if source not in STATES:
            errors.append(f"{prefix}.source must be a frozen fallback state")
        if event not in EVENTS:
            errors.append(f"{prefix}.event must be a frozen fallback event")
        if target not in STATES:
            errors.append(f"{prefix}.target must be a frozen fallback state")
        if not _text(reason):
            errors.append(f"{prefix}.reason must be non-empty text")
    if tuple(actual) != TRANSITIONS:
        errors.append("transitions must exactly match the frozen fallback transition order")
    return errors


def _validate_cases(value: Any) -> list[str]:
    errors: list[str] = []
    if not isinstance(value, list):
        return ["cases must contain exactly six fallback state-machine cases"]
    if len(value) != len(REQUIRED_CASES):
        errors.append("cases must contain exactly six fallback state-machine cases")
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
        for key in ("transition", "expected", "source_test"):
            if not _text(case.get(key)):
                errors.append(f"{prefix}.{key} must be non-empty text")
        status = case.get("status")
        if not isinstance(status, str) or status not in ITEM_STATUSES:
            errors.append(f"{prefix}.status must remain planned, pending, observed, or issue")
        _references(case.get("evidence"), f"{prefix}.evidence", errors, allow_none=isinstance(status, str) and status in {"planned", "pending"})
    if len(ids) != len(set(ids)):
        errors.append("cases.id values must be unique")
    if tuple(ids) != REQUIRED_CASES:
        errors.append("cases must exactly match the frozen fallback-case order")
    return errors


def validate_index(value: Any) -> list[str]:
    """Return blocking errors; empty means ready for the still-open review gate."""
    if not isinstance(value, dict):
        return ["index must be an object"]
    errors: list[str] = []
    if value.get("schema") != SCHEMA:
        errors.append(f"schema must be {SCHEMA}")
    human_review_status = value.get("human_review_status")
    if not isinstance(human_review_status, str) or human_review_status not in OPEN_STATUSES:
        errors.append("human_review_status must remain pending, not_performed, in_progress, or failed")
    native_render_status = value.get("native_render_status")
    if not isinstance(native_render_status, str) or native_render_status not in {"not_run", "planned", "blocked"}:
        errors.append("native_render_status must remain not_run, planned, or blocked")
    for key in ("source_revision", "contract_source", "reviewer_required", "open_gate_reason"):
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
    if value.get("fallback_text") != FALLBACK_TEXT:
        errors.append("fallback_text must be [inaudible]")
    if value.get("states") is None:
        errors.append("states is required")
    if value.get("transitions") is None:
        errors.append("transitions is required")
    errors.extend(_validate_states(value.get("states")))
    errors.extend(_validate_transitions(value.get("transitions")))
    errors.extend(_validate_cases(value.get("cases")))
    return errors


def validate(path: str | Path) -> list[str]:
    try:
        value = json.loads(Path(path).read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"index unreadable: {exc}"]
    return validate_index(value)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("index", type=Path)
    args = parser.parse_args(argv)
    errors = validate(args.index)
    if errors:
        print("ACCESSIBILITY_CAPTION_FALLBACK_STATE_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("ACCESSIBILITY_CAPTION_FALLBACK_STATE_READY: human review remains open")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
