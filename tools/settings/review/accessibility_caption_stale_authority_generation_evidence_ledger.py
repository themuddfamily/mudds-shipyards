#!/usr/bin/env python3
"""Validate stale-authority generation scenarios for caption fallback.

The ledger freezes scenario outcomes for current, stale, reset, and
non-presentation authority payloads.  It does not execute runtime code,
mutate settings or gameplay, play audio, render UI, or claim human review.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

SCHEMA = "accessibility_caption_stale_authority_generation_evidence_v1"
OPEN_STATUSES = {"pending", "not_performed", "in_progress", "failed"}
ITEM_STATUSES = {"planned", "pending", "observed", "issue"}
EVIDENCE_KINDS = {"log", "video", "image", "report"}
SHA = re.compile(r"^[0-9a-f]{40,64}$")
SCENARIO_IDS = (
    "current_generation_presentation",
    "older_generation_payload",
    "reset_generation_boundary",
    "audio_authority_claim",
    "settings_authority_claim",
    "gameplay_authority_claim",
)
SCENARIO_RULES = {
    "current_generation_presentation": {"generation_relation": "equal", "result": "accepted", "reason": "current_generation", "authority": "presentation_only"},
    "older_generation_payload": {"generation_relation": "less_than_current", "result": "rejected", "reason": "stale_generation", "authority": "none"},
    "reset_generation_boundary": {"generation_relation": "increment_one", "result": "old_payload_rejected", "reason": "stale_generation", "authority": "lifecycle_only"},
    "audio_authority_claim": {"generation_relation": "equal", "result": "rejected", "reason": "authority_boundary", "authority": "none"},
    "settings_authority_claim": {"generation_relation": "equal", "result": "rejected", "reason": "authority_boundary", "authority": "none"},
    "gameplay_authority_claim": {"generation_relation": "equal", "result": "rejected", "reason": "authority_boundary", "authority": "none"},
}
REQUIRED_CHECKS = (
    "current_generation_acceptance",
    "older_generation_rejection",
    "reset_invalidates_old_payload",
    "audio_authority_rejection",
    "settings_authority_rejection",
    "gameplay_authority_rejection",
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


def _validate_scenarios(value: Any) -> list[str]:
    errors: list[str] = []
    if not isinstance(value, list):
        return ["scenarios must contain exactly six ordered stale-authority scenarios"]
    if len(value) != len(SCENARIO_IDS):
        errors.append("scenarios must contain exactly six ordered stale-authority scenarios")
    ids: list[str] = []
    for index, scenario in enumerate(value):
        prefix = f"scenarios[{index}]"
        if not isinstance(scenario, dict):
            errors.append(f"{prefix} must be an object")
            continue
        scenario_id = scenario.get("id")
        if scenario_id not in SCENARIO_IDS:
            errors.append(f"{prefix}.id must be one of the frozen stale-authority scenarios")
        else:
            ids.append(scenario_id)
            expected = SCENARIO_RULES[scenario_id]
            for key in ("generation_relation", "result", "reason", "authority"):
                if scenario.get(key) != expected[key]:
                    errors.append(f"{prefix}.{key} must match its stale-authority scenario")
        if not _text(scenario.get("expected_behavior")):
            errors.append(f"{prefix}.expected_behavior must be non-empty text")
        status = scenario.get("status")
        if not isinstance(status, str) or status not in ITEM_STATUSES:
            errors.append(f"{prefix}.status must remain planned, pending, observed, or issue")
        _references(scenario.get("evidence"), f"{prefix}.evidence", errors, allow_none=isinstance(status, str) and status in {"planned", "pending"})
    if len(ids) != len(set(ids)):
        errors.append("scenarios.id values must be unique")
    if tuple(ids) != SCENARIO_IDS:
        errors.append("scenarios must exactly match the frozen stale-authority order")
    return errors


def _validate_checks(value: Any) -> list[str]:
    errors: list[str] = []
    if not isinstance(value, list):
        return ["checks must contain exactly six stale-authority checks"]
    if len(value) != len(REQUIRED_CHECKS):
        errors.append("checks must contain exactly six stale-authority checks")
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
        errors.append("checks must exactly match the frozen stale-authority check order")
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
    if value.get("rejection_policy") != "stale_generation_or_authority_boundary":
        errors.append("rejection_policy must be stale_generation_or_authority_boundary")
    if value.get("limits") != LIMITS:
        errors.append("limits must exactly match the frozen stale-authority bounds")
    errors.extend(_validate_scenarios(value.get("scenarios")))
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
        print("ACCESSIBILITY_CAPTION_STALE_AUTHORITY_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("ACCESSIBILITY_CAPTION_STALE_AUTHORITY_READY: human review remains open")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
