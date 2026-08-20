#!/usr/bin/env python3
"""Validate authority boundaries around accessibility caption fallback.

The validator freezes which systems may observe, configure, decide, and
present a caption.  It does not play audio, mutate settings or gameplay,
enqueue runtime content, render UI, or claim human accessibility review.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

SCHEMA = "accessibility_caption_fallback_authority_boundary_evidence_v1"
OPEN_STATUSES = {"pending", "not_performed", "in_progress", "failed"}
ITEM_STATUSES = {"planned", "pending", "observed", "issue"}
EVIDENCE_KINDS = {"log", "video", "image", "report"}
SHA = re.compile(r"^[0-9a-f]{40,64}$")
AUTHORITY_KEYS = (
    "presentation_only",
    "audio_authority",
    "audio_playback",
    "caption_queue_authority",
    "settings_authority",
    "gameplay_authority",
    "activity_authority",
    "reward_authority",
    "ship_authority",
    "berth_authority",
    "save_authority",
    "network_authority",
    "uses_wall_clock",
)
AUTHORITY_VALUES = {
    "presentation_only": True,
    "audio_authority": False,
    "audio_playback": False,
    "caption_queue_authority": False,
    "settings_authority": False,
    "gameplay_authority": False,
    "activity_authority": False,
    "reward_authority": False,
    "ship_authority": False,
    "berth_authority": False,
    "save_authority": False,
    "network_authority": False,
    "uses_wall_clock": False,
}
BOUNDARY_IDS = (
    "audio_observation",
    "settings_profile",
    "caption_decision",
    "queue_handoff",
    "fallback_text",
)
BOUNDARY_RULES = {
    "audio_observation": {"owner": "audio_system", "direction": "input", "mutates": False, "scope": "observation_only"},
    "settings_profile": {"owner": "settings_owner", "direction": "input", "mutates": False, "scope": "policy_snapshot_only"},
    "caption_decision": {"owner": "caption_accessibility_contract", "direction": "decision", "mutates": False, "scope": "presentation_only"},
    "queue_handoff": {"owner": "caption_presentation_service", "direction": "output", "mutates": False, "scope": "caller_handoff_only"},
    "fallback_text": {"owner": "caption_accessibility_contract", "direction": "output", "mutates": False, "scope": "stable_text_only"},
}
REQUIRED_CASES = (
    "audio_observation_not_playback",
    "settings_profile_not_mutated",
    "decision_accept_reject_only",
    "queue_handoff_not_owned",
    "fallback_text_not_audio",
    "forbidden_gameplay_effects",
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


def _validate_boundaries(value: Any) -> list[str]:
    errors: list[str] = []
    if not isinstance(value, list):
        return ["boundaries must contain exactly five ordered authority boundaries"]
    if len(value) != len(BOUNDARY_IDS):
        errors.append("boundaries must contain exactly five ordered authority boundaries")
    ids: list[str] = []
    for index, boundary in enumerate(value):
        prefix = f"boundaries[{index}]"
        if not isinstance(boundary, dict):
            errors.append(f"{prefix} must be an object")
            continue
        boundary_id = boundary.get("id")
        if boundary_id not in BOUNDARY_IDS:
            errors.append(f"{prefix}.id must be one of the frozen authority boundaries")
        else:
            ids.append(boundary_id)
            expected = BOUNDARY_RULES[boundary_id]
            for key in ("owner", "direction", "mutates", "scope"):
                if boundary.get(key) != expected[key]:
                    errors.append(f"{prefix}.{key} must match its authority boundary")
        if not _text(boundary.get("expected_behavior")):
            errors.append(f"{prefix}.expected_behavior must be non-empty text")
        status = boundary.get("status")
        if not isinstance(status, str) or status not in ITEM_STATUSES:
            errors.append(f"{prefix}.status must remain planned, pending, observed, or issue")
        _references(boundary.get("evidence"), f"{prefix}.evidence", errors, allow_none=isinstance(status, str) and status in {"planned", "pending"})
    if len(ids) != len(set(ids)):
        errors.append("boundaries.id values must be unique")
    if tuple(ids) != BOUNDARY_IDS:
        errors.append("boundaries must exactly match the frozen authority-boundary order")
    return errors


def _validate_cases(value: Any) -> list[str]:
    errors: list[str] = []
    if not isinstance(value, list):
        return ["cases must contain exactly six authority-boundary cases"]
    if len(value) != len(REQUIRED_CASES):
        errors.append("cases must contain exactly six authority-boundary cases")
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
        if case.get("boundary") not in BOUNDARY_IDS and case.get("boundary") != "authority_roster":
            errors.append(f"{prefix}.boundary must name a frozen authority boundary or authority_roster")
        status = case.get("status")
        if not isinstance(status, str) or status not in ITEM_STATUSES:
            errors.append(f"{prefix}.status must remain planned, pending, observed, or issue")
        _references(case.get("evidence"), f"{prefix}.evidence", errors, allow_none=isinstance(status, str) and status in {"planned", "pending"})
    if len(ids) != len(set(ids)):
        errors.append("cases.id values must be unique")
    if tuple(ids) != REQUIRED_CASES:
        errors.append("cases must exactly match the frozen authority-boundary order")
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
    for key in ("source_revision", "contract_source", "service_source", "reviewer_required", "open_gate_reason"):
        if not _text(value.get(key)):
            errors.append(f"{key} must be non-empty text")
    for key, expected in AUTHORITY_VALUES.items():
        if value.get(key) is not expected:
            errors.append(f"{key} must be {str(expected).lower()}")
    if value.get("contract_id") != "caption-accessibility-contract":
        errors.append("contract_id must identify caption-accessibility-contract")
    if value.get("service_id") != "caption-presentation-service":
        errors.append("service_id must identify caption-presentation-service")
    if value.get("decision_outputs") != ["accepted", "reason", "stable_id", "category", "speaker", "text"]:
        errors.append("decision_outputs must exactly match the detached caption decision fields")
    if value.get("forbidden_effects") != ["audio_playback", "settings_mutation", "gameplay_mutation", "reward_mutation", "network_mutation"]:
        errors.append("forbidden_effects must exactly match the non-presentation effects")
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
        print("ACCESSIBILITY_CAPTION_AUTHORITY_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("ACCESSIBILITY_CAPTION_AUTHORITY_READY: human review remains open")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
