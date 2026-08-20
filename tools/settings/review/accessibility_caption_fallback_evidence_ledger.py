#!/usr/bin/env python3
"""Validate the accessibility caption/text-fallback evidence ledger.

The ledger freezes caption categories, verbosity filters, bounded text fields,
inaudible fallback wording, and reduced visual policies. It does not enqueue
captions, play audio, render UI, or claim human accessibility review.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

SCHEMA = "accessibility_caption_fallback_evidence_v1"
OPEN_STATUSES = {"pending", "not_performed", "in_progress", "failed"}
ITEM_STATUSES = {"planned", "pending", "observed", "issue"}
EVIDENCE_KINDS = {"log", "video", "image", "report"}
SHA = re.compile(r"^[0-9a-f]{40,64}$")
SETTING_KEYS = ("captions_enabled", "verbosity", "high_contrast", "reduced_motion", "reduced_flash")
CATEGORIES = ("dialogue", "radio", "system", "ambient")
VERBOSITY_VALUES = ("all", "dialogue_only", "important_only", "off")
REQUIRED_CASES = (
    "inaudible_empty_text", "all_verbosity", "dialogue_only_filter",
    "important_only_filter", "off_filter", "high_contrast_policy",
    "reduced_motion_policy", "reduced_flash_policy",
)
LIMITS = {
    "max_stable_id_characters": 64,
    "max_speaker_characters": 64,
    "max_text_characters": 512,
    "min_duration_physics_seconds": 0.1,
    "max_duration_physics_seconds": 30.0,
    "min_priority": 0,
    "max_priority": 100,
    "max_stored_captions": 8,
    "max_accepted_ids": 1024,
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


def _validate_cases(value: Any) -> list[str]:
    errors: list[str] = []
    if not isinstance(value, list):
        return ["cases must contain exactly eight caption fallback cases"]
    if len(value) != len(REQUIRED_CASES):
        errors.append("cases must contain exactly eight caption fallback cases")
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
        for key in ("expected", "source_test"):
            if not _text(case.get(key)):
                errors.append(f"{prefix}.{key} must be non-empty text")
        status = case.get("status")
        if not isinstance(status, str) or status not in ITEM_STATUSES:
            errors.append(f"{prefix}.status must remain planned, pending, observed, or issue")
        _references(case.get("evidence"), f"{prefix}.evidence", errors, allow_none=isinstance(status, str) and status in {"planned", "pending"})
    if len(ids) != len(set(ids)):
        errors.append("cases.id values must be unique")
    if tuple(ids) != REQUIRED_CASES:
        errors.append("cases must exactly match the frozen caption fallback order")
    return errors


def validate_ledger(value: Any) -> list[str]:
    """Return blocking errors; empty means ready for the still-open human gate."""
    if not isinstance(value, dict):
        return ["ledger must be an object"]
    errors: list[str] = []
    if value.get("schema") != SCHEMA:
        errors.append(f"schema must be {SCHEMA}")
    if value.get("human_review_status") not in OPEN_STATUSES:
        errors.append("human_review_status must remain pending, not_performed, in_progress, or failed")
    if value.get("native_render_status") not in {"not_run", "planned", "blocked"}:
        errors.append("native_render_status must remain not_run, planned, or blocked")
    for key in ("source_revision", "contract_source", "service_source", "reviewer_required", "open_gate_reason"):
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
    if value.get("setting_keys") != list(SETTING_KEYS):
        errors.append("setting_keys must exactly match the five caption accessibility settings")
    if value.get("categories") != list(CATEGORIES):
        errors.append("categories must exactly match dialogue, radio, system, ambient")
    if value.get("verbosity_values") != list(VERBOSITY_VALUES):
        errors.append("verbosity_values must exactly match the four frozen modes")
    if value.get("inaudible_fallback_text") != "[inaudible]":
        errors.append("inaudible_fallback_text must be [inaudible]")
    if value.get("limits") != LIMITS:
        errors.append("limits must exactly match the frozen caption event/service bounds")
    if value.get("reduced_motion_policy") != "steady_no_motion":
        errors.append("reduced_motion_policy must be steady_no_motion")
    if value.get("reduced_flash_policy") != "steady_no_flash":
        errors.append("reduced_flash_policy must be steady_no_flash")
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
        print("ACCESSIBILITY_CAPTION_FALLBACK_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("ACCESSIBILITY_CAPTION_FALLBACK_READY: human review remains open")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
