#!/usr/bin/env python3
"""Validate the accessibility reduced-motion/reduced-flash policy ledger.

The ledger freezes steady visual alternatives across cue, caption, HUD, and
loading presenters. It cannot run a viewport, inspect animation frames, or
claim that a human found the reduced treatment comfortable.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

SCHEMA = "accessibility_reduced_motion_flash_policy_evidence_v1"
OPEN_STATUSES = {"pending", "not_performed", "in_progress", "failed"}
ITEM_STATUSES = {"planned", "pending", "observed", "issue"}
EVIDENCE_KINDS = {"log", "video", "image", "report"}
SHA = re.compile(r"^[0-9a-f]{40,64}$")
SETTING_KEYS = ("reduced_motion", "reduced_flash", "captions_enabled")
POLICY_IDS = (
    "visual_flash_strength", "visual_motion_strength", "caption_flash_policy",
    "caption_motion_policy", "hud_damage_feedback", "hud_toast_fade",
    "loading_transition", "atomic_accessibility_flags",
)
REQUIRED_CHECKS = (
    "visual_strength_zero", "caption_steady_flash", "caption_steady_motion",
    "hud_damage_hold", "hud_toast_no_fade", "loading_no_fade_no_pulse",
    "atomic_flags", "reentry_persistence",
)
POLICIES = {
    "visual_flash_strength": {"normal": "input_strength", "reduced": "0.0"},
    "visual_motion_strength": {"normal": "input_strength", "reduced": "0.0"},
    "caption_flash_policy": {"normal": "consumer_standard", "reduced": "steady_no_flash"},
    "caption_motion_policy": {"normal": "consumer_standard", "reduced": "steady_no_motion"},
    "hud_damage_feedback": {"normal": "fade", "reduced": "hold_0.45s_then_clear"},
    "hud_toast_fade": {"normal": "0.35s", "reduced": "0.0s"},
    "loading_transition": {"normal": "fade_and_caret_pulse", "reduced": "instant_and_steady_caret"},
    "atomic_accessibility_flags": {"normal": "one_profile_transaction", "reduced": "one_profile_transaction"},
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
        if reference.get("kind") not in EVIDENCE_KINDS:
            errors.append(f"{label}.kind must be log, video, image, or report")
        if not _text(reference.get("path")):
            errors.append(f"{label}.path must be non-empty text")
        if not _sha(reference.get("sha256")):
            errors.append(f"{label}.sha256 must be a lowercase digest")
        path, digest = reference.get("path"), reference.get("sha256")
        if isinstance(path, str) and isinstance(digest, str):
            identity = (path, digest)
            if identity in seen:
                errors.append(f"{label} duplicates an earlier reference")
            seen.add(identity)


def _validate_policies(value: Any) -> list[str]:
    errors: list[str] = []
    if not isinstance(value, list):
        return ["policies must contain exactly eight reduced-motion/flash policies"]
    if len(value) != len(POLICY_IDS):
        errors.append("policies must contain exactly eight reduced-motion/flash policies")
    ids: list[str] = []
    for index, policy in enumerate(value):
        prefix = f"policies[{index}]"
        if not isinstance(policy, dict):
            errors.append(f"{prefix} must be an object")
            continue
        policy_id = policy.get("id")
        if policy_id not in POLICY_IDS:
            errors.append(f"{prefix}.id must be one of the eight frozen policies")
        else:
            ids.append(policy_id)
            expected = POLICIES[policy_id]
            if policy.get("normal") != expected["normal"] or policy.get("reduced") != expected["reduced"]:
                errors.append(f"{prefix} must match the frozen normal/reduced policy")
        if not _text(policy.get("owner")):
            errors.append(f"{prefix}.owner must be non-empty text")
        status = policy.get("status")
        if not isinstance(status, str) or status not in ITEM_STATUSES:
            errors.append(f"{prefix}.status must remain planned, pending, observed, or issue")
        _references(policy.get("evidence"), f"{prefix}.evidence", errors, allow_none=isinstance(status, str) and status in {"planned", "pending"})
    if len(ids) != len(set(ids)):
        errors.append("policies.id values must be unique")
    if tuple(ids) != POLICY_IDS:
        errors.append("policies must exactly match the frozen policy order")
    return errors


def _validate_checks(value: Any) -> list[str]:
    errors: list[str] = []
    if not isinstance(value, list):
        return ["checks must contain exactly eight reduced-motion/flash checks"]
    if len(value) != len(REQUIRED_CHECKS):
        errors.append("checks must contain exactly eight reduced-motion/flash checks")
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
        errors.append("checks must exactly match the frozen reduced policy order")
    return errors


def validate_ledger(value: Any) -> list[str]:
    """Return blocking errors; empty means ready for the still-open visual gate."""
    if not isinstance(value, dict):
        return ["ledger must be an object"]
    errors: list[str] = []
    if value.get("schema") != SCHEMA:
        errors.append(f"schema must be {SCHEMA}")
    if value.get("human_review_status") not in OPEN_STATUSES:
        errors.append("human_review_status must remain pending, not_performed, in_progress, or failed")
    if value.get("native_render_status") not in {"not_run", "planned", "blocked"}:
        errors.append("native_render_status must remain not_run, planned, or blocked")
    for key in ("source_revision", "visual_source", "caption_source", "hud_source", "loading_source", "reviewer_required", "open_gate_reason"):
        if not _text(value.get(key)):
            errors.append(f"{key} must be non-empty text")
    for key, expected in (
        ("human_review_performed", False),
        ("native_render_performed", False),
        ("detached_contract_tests_only", True),
        ("presentation_only", True),
        ("gameplay_authority", False),
        ("audio_authority", False),
        ("settings_authority", False),
    ):
        if value.get(key) is not expected:
            errors.append(f"{key} must be {str(expected).lower()}")
    if value.get("setting_keys") != list(SETTING_KEYS):
        errors.append("setting_keys must exactly match reduced motion, reduced flash, and captions")
    if value.get("normal_policy") != "consumer_standard":
        errors.append("normal_policy must be consumer_standard")
    if value.get("reduced_motion_policy") != "steady_no_motion":
        errors.append("reduced_motion_policy must be steady_no_motion")
    if value.get("reduced_flash_policy") != "steady_no_flash":
        errors.append("reduced_flash_policy must be steady_no_flash")
    errors.extend(_validate_policies(value.get("policies")))
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
        print("ACCESSIBILITY_REDUCED_POLICY_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("ACCESSIBILITY_REDUCED_POLICY_READY: human visual review remains open")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
