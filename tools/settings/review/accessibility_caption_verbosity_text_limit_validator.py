#!/usr/bin/env python3
"""Validate caption verbosity and text-limit evidence.

This detached validator freezes filter semantics and event boundaries for the
caption accessibility contract. It does not enqueue captions, play audio, or
claim human readability review.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

SCHEMA = "accessibility_caption_verbosity_text_limit_evidence_v1"
OPEN_STATUSES = {"pending", "not_performed", "in_progress", "failed"}
ITEM_STATUSES = {"planned", "pending", "observed", "issue"}
EVIDENCE_KINDS = {"log", "video", "image", "report"}
SHA = re.compile(r"^[0-9a-f]{40,64}$")
CATEGORIES = ("dialogue", "radio", "system", "ambient")
VERBOSITY_VALUES = ("all", "dialogue_only", "important_only", "off")
VERBOSITY_RULES = {
    "all": {"included_categories": list(CATEGORIES), "minimum_priority": 0},
    "dialogue_only": {"included_categories": ["dialogue"], "minimum_priority": 0},
    "important_only": {"included_categories": list(CATEGORIES), "minimum_priority": 50},
    "off": {"included_categories": [], "minimum_priority": 101},
}
LIMITS = {
    "max_stable_id_characters": 64,
    "max_speaker_characters": 64,
    "max_text_characters": 512,
    "min_duration_physics_seconds": 0.1,
    "max_duration_physics_seconds": 30.0,
    "min_priority": 0,
    "max_priority": 100,
}
REQUIRED_CASES = (
    "stable_id_lowercase", "speaker_nonblank", "text_nonblank", "text_max_512",
    "duration_bounds", "priority_bounds", "nul_rejected", "inaudible_fallback",
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


def _validate_modes(value: Any) -> list[str]:
    errors: list[str] = []
    if not isinstance(value, list):
        return ["verbosity_modes must contain exactly four ordered modes"]
    if len(value) != len(VERBOSITY_VALUES):
        errors.append("verbosity_modes must contain exactly four ordered modes")
    ids: list[str] = []
    for index, mode in enumerate(value):
        prefix = f"verbosity_modes[{index}]"
        if not isinstance(mode, dict):
            errors.append(f"{prefix} must be an object")
            continue
        mode_id = mode.get("id")
        if mode_id not in VERBOSITY_VALUES:
            errors.append(f"{prefix}.id must be one of the four frozen verbosity values")
        else:
            ids.append(mode_id)
            expected = VERBOSITY_RULES[mode_id]
            if mode.get("included_categories") != expected["included_categories"]:
                errors.append(f"{prefix}.included_categories must match its verbosity rule")
            if mode.get("minimum_priority") != expected["minimum_priority"]:
                errors.append(f"{prefix}.minimum_priority must match its verbosity rule")
        if not _text(mode.get("description")):
            errors.append(f"{prefix}.description must be non-empty text")
        status = mode.get("status")
        if not isinstance(status, str) or status not in ITEM_STATUSES:
            errors.append(f"{prefix}.status must remain planned, pending, observed, or issue")
        _references(mode.get("evidence"), f"{prefix}.evidence", errors, allow_none=isinstance(status, str) and status in {"planned", "pending"})
    if len(ids) != len(set(ids)):
        errors.append("verbosity_modes.id values must be unique")
    if tuple(ids) != VERBOSITY_VALUES:
        errors.append("verbosity_modes must exactly match the frozen mode order")
    return errors


def _validate_cases(value: Any) -> list[str]:
    errors: list[str] = []
    if not isinstance(value, list):
        return ["boundary_cases must contain exactly eight text-limit cases"]
    if len(value) != len(REQUIRED_CASES):
        errors.append("boundary_cases must contain exactly eight text-limit cases")
    ids: list[str] = []
    for index, case in enumerate(value):
        prefix = f"boundary_cases[{index}]"
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
        errors.append("boundary_cases.id values must be unique")
    if tuple(ids) != REQUIRED_CASES:
        errors.append("boundary_cases must exactly match the frozen case order")
    return errors


def validate_ledger(value: Any) -> list[str]:
    """Return blocking errors; empty means ready for the still-open human gate."""
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
    if value.get("categories") != list(CATEGORIES):
        errors.append("categories must exactly match dialogue, radio, system, ambient")
    if value.get("limits") != LIMITS:
        errors.append("limits must exactly match the frozen caption event bounds")
    if value.get("inaudible_fallback_text") != "[inaudible]":
        errors.append("inaudible_fallback_text must be [inaudible]")
    if value.get("verbosity_modes") is None:
        errors.append("verbosity_modes is required")
    errors.extend(_validate_modes(value.get("verbosity_modes")))
    errors.extend(_validate_cases(value.get("boundary_cases")))
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
        print("ACCESSIBILITY_CAPTION_LIMIT_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("ACCESSIBILITY_CAPTION_LIMIT_READY: human review remains open")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
