#!/usr/bin/env python3
"""Validate caption authority, reentry, and generation evidence.

The ledger freezes the presentation service's signal-dispatch guard and reset
generation contract.  It does not execute callbacks, enqueue captions, play
audio, render UI, or claim human accessibility review.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

SCHEMA = "accessibility_caption_authority_reentry_generation_evidence_v1"
OPEN_STATUSES = {"pending", "not_performed", "in_progress", "failed"}
ITEM_STATUSES = {"planned", "pending", "observed", "issue"}
EVIDENCE_KINDS = {"log", "video", "image", "report"}
SHA = re.compile(r"^[0-9a-f]{40,64}$")
AUTHORITY_VALUES = {
    "presentation_only": True,
    "audio_authority": False,
    "audio_playback": False,
    "caption_queue_authority": False,
    "settings_authority": False,
    "gameplay_authority": False,
    "activity_authority": False,
    "reward_authority": False,
    "network_authority": False,
}
CHECK_IDS = (
    "signal_dispatch_starts_after_commit",
    "reentrant_enqueue_rejected",
    "reentrant_advance_rejected",
    "reentrant_reset_rejected",
    "reentrant_flags_rejected",
    "dispatch_guard_clears_after_emit",
    "reset_increments_generation",
    "reentrant_generation_unchanged",
)
CHECK_RULES = {
    "signal_dispatch_starts_after_commit": {"result": "signal_dispatch_active", "mutation": "post_commit_only", "generation": "unchanged"},
    "reentrant_enqueue_rejected": {"result": "reentrant_call", "mutation": "none", "generation": "unchanged"},
    "reentrant_advance_rejected": {"result": "reentrant_call", "mutation": "none", "generation": "unchanged"},
    "reentrant_reset_rejected": {"result": "reentrant_call", "mutation": "none", "generation": "unchanged"},
    "reentrant_flags_rejected": {"result": "reentrant_call", "mutation": "none", "generation": "unchanged"},
    "dispatch_guard_clears_after_emit": {"result": "dispatch_idle", "mutation": "next_call_allowed", "generation": "unchanged"},
    "reset_increments_generation": {"result": "reset", "mutation": "queue_and_ledger_cleared", "generation": "increment_one"},
    "reentrant_generation_unchanged": {"result": "reentrant_call", "mutation": "none", "generation": "unchanged"},
}
POST_COMMIT_ORDER = ("revision_increment", "snapshot_capture", "signal_emit", "guard_clear")
LIMITS = {"minimum_generation": 0, "generation_step_after_reset": 1, "maximum_safe_sequence": 9007199254740991}


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
        return ["checks must contain exactly eight ordered authority/reentry checks"]
    if len(value) != len(CHECK_IDS):
        errors.append("checks must contain exactly eight ordered authority/reentry checks")
    ids: list[str] = []
    for index, check in enumerate(value):
        prefix = f"checks[{index}]"
        if not isinstance(check, dict):
            errors.append(f"{prefix} must be an object")
            continue
        check_id = check.get("id")
        if check_id not in CHECK_IDS:
            errors.append(f"{prefix}.id must be one of the frozen authority/reentry checks")
        else:
            ids.append(check_id)
            expected = CHECK_RULES[check_id]
            expected_fields = {"expected_result": "result", "mutation": "mutation", "generation": "generation"}
            for key, rule_key in expected_fields.items():
                if check.get(key) != expected[rule_key]:
                    errors.append(f"{prefix}.{key} must match its authority/reentry check")
        if not _text(check.get("expected_behavior")):
            errors.append(f"{prefix}.expected_behavior must be non-empty text")
        status = check.get("status")
        if not isinstance(status, str) or status not in ITEM_STATUSES:
            errors.append(f"{prefix}.status must remain planned, pending, observed, or issue")
        _references(check.get("evidence"), f"{prefix}.evidence", errors, allow_none=isinstance(status, str) and status in {"planned", "pending"})
    if len(ids) != len(set(ids)):
        errors.append("checks.id values must be unique")
    if tuple(ids) != CHECK_IDS:
        errors.append("checks must exactly match the frozen authority/reentry order")
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
    for key in ("source_revision", "service_source", "signal_source", "reviewer_required", "open_gate_reason"):
        if not _text(value.get(key)):
            errors.append(f"{key} must be non-empty text")
    for key, expected in AUTHORITY_VALUES.items():
        if value.get(key) is not expected:
            errors.append(f"{key} must be {str(expected).lower()}")
    if value.get("service_id") != "caption-presentation-service":
        errors.append("service_id must identify caption-presentation-service")
    if value.get("dispatch_guard") != "signal_dispatch_active":
        errors.append("dispatch_guard must be signal_dispatch_active")
    if value.get("reentrant_reason") != "reentrant_call":
        errors.append("reentrant_reason must be reentrant_call")
    if value.get("post_commit_order") != list(POST_COMMIT_ORDER):
        errors.append("post_commit_order must exactly match revision, snapshot, emit, clear")
    if value.get("limits") != LIMITS:
        errors.append("limits must exactly match the frozen reentry-generation bounds")
    if value.get("generation_fields") != ["generation", "revision"]:
        errors.append("generation_fields must exactly match generation and revision")
    if value.get("generation_monotonic") is not True:
        errors.append("generation_monotonic must be true")
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
        print("ACCESSIBILITY_CAPTION_REENTRY_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("ACCESSIBILITY_CAPTION_REENTRY_READY: human review remains open")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
