#!/usr/bin/env python3
"""Validate lifecycle-phase evidence for caption generation authority/staleness.

This ledger freezes the relation between a payload's generation, the current
service generation, and presentation-only authority.  It does not execute
runtime callbacks, mutate state, render UI, play audio, or claim human review.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

SCHEMA = "accessibility_caption_generation_authority_stale_evidence_v1"
OPEN_STATUSES = {"pending", "not_performed", "in_progress", "failed"}
ITEM_STATUSES = {"planned", "pending", "observed", "issue"}
EVIDENCE_KINDS = {"log", "video", "image", "report"}
SHA = re.compile(r"^[0-9a-f]{40,64}$")
PHASE_IDS = (
    "current_generation",
    "after_reset_generation",
    "older_generation_payload",
    "future_generation_payload",
    "external_authority_payload",
)
PHASE_RULES = {
    "current_generation": {"relation": "equal", "result": "accepted", "reason": "current_generation", "authority": "presentation_only"},
    "after_reset_generation": {"relation": "equal_after_increment", "result": "accepted", "reason": "current_generation", "authority": "presentation_only"},
    "older_generation_payload": {"relation": "less_than_current", "result": "rejected", "reason": "stale_generation", "authority": "none"},
    "future_generation_payload": {"relation": "greater_than_current", "result": "rejected", "reason": "future_generation", "authority": "none"},
    "external_authority_payload": {"relation": "equal", "result": "rejected", "reason": "authority_boundary", "authority": "none"},
}
REQUIRED_CHECKS = (
    "current_payload_acceptance",
    "reset_payload_acceptance",
    "older_payload_rejection",
    "future_payload_rejection",
    "external_authority_rejection",
    "stale_payload_no_mutation",
)
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


def _validate_phases(value: Any) -> list[str]:
    errors: list[str] = []
    if not isinstance(value, list):
        return ["phases must contain exactly five ordered generation-authority phases"]
    if len(value) != len(PHASE_IDS):
        errors.append("phases must contain exactly five ordered generation-authority phases")
    ids: list[str] = []
    for index, phase in enumerate(value):
        prefix = f"phases[{index}]"
        if not isinstance(phase, dict):
            errors.append(f"{prefix} must be an object")
            continue
        phase_id = phase.get("id")
        if phase_id not in PHASE_IDS:
            errors.append(f"{prefix}.id must be one of the frozen generation-authority phases")
        else:
            ids.append(phase_id)
            expected = PHASE_RULES[phase_id]
            for key in ("relation", "result", "reason", "authority"):
                if phase.get(key) != expected[key]:
                    errors.append(f"{prefix}.{key} must match its generation-authority phase")
        if not _text(phase.get("expected_behavior")):
            errors.append(f"{prefix}.expected_behavior must be non-empty text")
        status = phase.get("status")
        if not isinstance(status, str) or status not in ITEM_STATUSES:
            errors.append(f"{prefix}.status must remain planned, pending, observed, or issue")
        _references(phase.get("evidence"), f"{prefix}.evidence", errors, allow_none=isinstance(status, str) and status in {"planned", "pending"})
    if len(ids) != len(set(ids)):
        errors.append("phases.id values must be unique")
    if tuple(ids) != PHASE_IDS:
        errors.append("phases must exactly match the frozen generation-authority order")
    return errors


def _validate_checks(value: Any) -> list[str]:
    errors: list[str] = []
    if not isinstance(value, list):
        return ["checks must contain exactly six generation-authority checks"]
    if len(value) != len(REQUIRED_CHECKS):
        errors.append("checks must contain exactly six generation-authority checks")
    ids: list[str] = []
    for index, check in enumerate(value):
        prefix = f"checks[{index}]"
        if not isinstance(check, dict):
            errors.append(f"{prefix} must be an object")
            continue
        check_id = check.get("id")
        if not _text(check_id):
            errors.append(f"{prefix}.id must be non-empty text")
        else:
            ids.append(check_id)
        for key in ("expected", "source_test"):
            if not _text(check.get(key)):
                errors.append(f"{prefix}.{key} must be non-empty text")
        status = check.get("status")
        if not isinstance(status, str) or status not in ITEM_STATUSES:
            errors.append(f"{prefix}.status must remain planned, pending, observed, or issue")
        _references(check.get("evidence"), f"{prefix}.evidence", errors, allow_none=isinstance(status, str) and status in {"planned", "pending"})
    if len(ids) != len(set(ids)):
        errors.append("checks.id values must be unique")
    if tuple(ids) != REQUIRED_CHECKS:
        errors.append("checks must exactly match the frozen generation-authority check order")
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
    for key in ("source_revision", "service_source", "contract_source", "consumer_boundary", "reviewer_required", "open_gate_reason"):
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
    if value.get("contract_id") != "caption-accessibility-contract":
        errors.append("contract_id must identify caption-accessibility-contract")
    if value.get("generation_owner") != "caption-presentation-service":
        errors.append("generation_owner must be caption-presentation-service")
    if value.get("authority_owner") != "caption-accessibility-contract":
        errors.append("authority_owner must be caption-accessibility-contract")
    if value.get("stale_rejection_owner") != "caption_consumer_boundary":
        errors.append("stale_rejection_owner must be caption_consumer_boundary")
    if value.get("generation_policy") != "monotonic_reset_increment":
        errors.append("generation_policy must be monotonic_reset_increment")
    if value.get("authority_policy") != "presentation_only":
        errors.append("authority_policy must be presentation_only")
    if value.get("stale_policy") != "reject_less_or_greater_generation":
        errors.append("stale_policy must reject_less_or_greater_generation")
    if value.get("limits") != LIMITS:
        errors.append("limits must exactly match the frozen generation-authority bounds")
    errors.extend(_validate_phases(value.get("phases")))
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
        print("ACCESSIBILITY_CAPTION_GENERATION_AUTHORITY_STALE_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("ACCESSIBILITY_CAPTION_GENERATION_AUTHORITY_STALE_READY: human review remains open")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
