#!/usr/bin/env python3
"""Validate the accessibility caption fallback-verbosity policy ledger.

The ledger freezes profile-mode filtering and the inaudible-text fallback
cases.  It is detached evidence bookkeeping: it does not mutate settings,
enqueue captions, play audio, render UI, or claim human accessibility review.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

SCHEMA = "accessibility_caption_fallback_verbosity_policy_evidence_v1"
OPEN_STATUSES = {"pending", "not_performed", "in_progress", "failed"}
ITEM_STATUSES = {"planned", "pending", "observed", "issue"}
EVIDENCE_KINDS = {"log", "video", "image", "report"}
SHA = re.compile(r"^[0-9a-f]{40,64}$")
PROFILE_KEYS = ("captions_enabled", "verbosity")
CATEGORIES = ("dialogue", "radio", "system", "ambient")
VERBOSITY_VALUES = ("all", "dialogue_only", "important_only", "off")
POLICY_RULES = {
    "all": {"included_categories": list(CATEGORIES), "minimum_priority": 0, "filter_reason": "none"},
    "dialogue_only": {"included_categories": ["dialogue"], "minimum_priority": 0, "filter_reason": "non_dialogue_category"},
    "important_only": {"included_categories": list(CATEGORIES), "minimum_priority": 50, "filter_reason": "priority_below_50"},
    "off": {"included_categories": [], "minimum_priority": 101, "filter_reason": "captions_disabled"},
}
REQUIRED_CASES = (
    "all_accepts_authored",
    "dialogue_only_filters_non_dialogue",
    "important_only_filters_low_priority",
    "off_rejects_all",
    "inaudible_empty_uses_fallback",
    "inaudible_text_preserved",
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


def _validate_policies(value: Any) -> list[str]:
    errors: list[str] = []
    if not isinstance(value, list):
        return ["policies must contain exactly four ordered verbosity policies"]
    if len(value) != len(VERBOSITY_VALUES):
        errors.append("policies must contain exactly four ordered verbosity policies")
    ids: list[str] = []
    for index, policy in enumerate(value):
        prefix = f"policies[{index}]"
        if not isinstance(policy, dict):
            errors.append(f"{prefix} must be an object")
            continue
        policy_id = policy.get("id")
        if policy_id not in VERBOSITY_VALUES:
            errors.append(f"{prefix}.id must be one of the four frozen verbosity values")
        else:
            ids.append(policy_id)
            expected = POLICY_RULES[policy_id]
            for key in ("included_categories", "minimum_priority", "filter_reason"):
                if policy.get(key) != expected[key]:
                    errors.append(f"{prefix}.{key} must match its verbosity policy")
        if policy.get("profile_keys") != list(PROFILE_KEYS):
            errors.append(f"{prefix}.profile_keys must cover captions_enabled and verbosity")
        if not _text(policy.get("expected_behavior")):
            errors.append(f"{prefix}.expected_behavior must be non-empty text")
        status = policy.get("status")
        if not isinstance(status, str) or status not in ITEM_STATUSES:
            errors.append(f"{prefix}.status must remain planned, pending, observed, or issue")
        _references(policy.get("evidence"), f"{prefix}.evidence", errors, allow_none=isinstance(status, str) and status in {"planned", "pending"})
    if len(ids) != len(set(ids)):
        errors.append("policies.id values must be unique")
    if tuple(ids) != VERBOSITY_VALUES:
        errors.append("policies must exactly match the frozen verbosity order")
    return errors


def _validate_cases(value: Any) -> list[str]:
    errors: list[str] = []
    if not isinstance(value, list):
        return ["cases must contain exactly six fallback-verbosity cases"]
    if len(value) != len(REQUIRED_CASES):
        errors.append("cases must contain exactly six fallback-verbosity cases")
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
        for key in ("mode", "expected", "source_test"):
            if not _text(case.get(key)):
                errors.append(f"{prefix}.{key} must be non-empty text")
        if case.get("mode") not in VERBOSITY_VALUES and case.get("mode") != "fallback_independent":
            errors.append(f"{prefix}.mode must name a frozen verbosity value or fallback_independent")
        status = case.get("status")
        if not isinstance(status, str) or status not in ITEM_STATUSES:
            errors.append(f"{prefix}.status must remain planned, pending, observed, or issue")
        _references(case.get("evidence"), f"{prefix}.evidence", errors, allow_none=isinstance(status, str) and status in {"planned", "pending"})
    if len(ids) != len(set(ids)):
        errors.append("cases.id values must be unique")
    if tuple(ids) != REQUIRED_CASES:
        errors.append("cases must exactly match the frozen fallback-verbosity order")
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
    if value.get("profile_keys") != list(PROFILE_KEYS):
        errors.append("profile_keys must exactly match captions_enabled and verbosity")
    if value.get("default_profile") != {"captions_enabled": True, "verbosity": "all"}:
        errors.append("default_profile must enable captions with all verbosity")
    if value.get("categories") != list(CATEGORIES):
        errors.append("categories must exactly match dialogue, radio, system, ambient")
    if value.get("verbosity_values") != list(VERBOSITY_VALUES):
        errors.append("verbosity_values must exactly match the four frozen modes")
    if value.get("fallback_text") != "[inaudible]":
        errors.append("fallback_text must be [inaudible]")
    errors.extend(_validate_policies(value.get("policies")))
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
        print("ACCESSIBILITY_CAPTION_VERBOSITY_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("ACCESSIBILITY_CAPTION_VERBOSITY_READY: human review remains open")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
