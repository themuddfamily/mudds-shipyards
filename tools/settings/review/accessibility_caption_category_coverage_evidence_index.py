#!/usr/bin/env python3
"""Validate the accessibility caption-category coverage evidence index.

The index freezes the four authored caption categories and the source-only
coverage checks required for each one.  It records review work without
pretending that a headless contract test rendered a readable caption.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

SCHEMA = "accessibility_caption_category_coverage_evidence_v1"
OPEN_STATUSES = {"pending", "not_performed", "in_progress", "failed"}
ITEM_STATUSES = {"planned", "pending", "observed", "issue"}
EVIDENCE_KINDS = {"log", "video", "image", "report"}
SHA = re.compile(r"^[0-9a-f]{40,64}$")
CATEGORIES = ("dialogue", "radio", "system", "ambient")
CATEGORY_LABELS = {
    "dialogue": "DIALOGUE",
    "radio": "RADIO",
    "system": "SYSTEM",
    "ambient": "AMBIENT",
}
SURFACE_FIELDS = ("category_label", "speaker_label", "text_label")
REQUIRED_CHECKS = (
    "category_roster",
    "dialogue_coverage",
    "radio_coverage",
    "system_coverage",
    "ambient_coverage",
    "unknown_category_rejected",
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


def _validate_coverage_rows(value: Any) -> list[str]:
    errors: list[str] = []
    if not isinstance(value, list):
        return ["coverage_rows must contain exactly four ordered category rows"]
    if len(value) != len(CATEGORIES):
        errors.append("coverage_rows must contain exactly four ordered category rows")
    ids: list[str] = []
    for index, row in enumerate(value):
        prefix = f"coverage_rows[{index}]"
        if not isinstance(row, dict):
            errors.append(f"{prefix} must be an object")
            continue
        row_id = row.get("id")
        category = row.get("category")
        if not _text(row_id):
            errors.append(f"{prefix}.id must be non-empty text")
        else:
            ids.append(row_id)
        if not isinstance(category, str) or category not in CATEGORIES:
            errors.append(f"{prefix}.category must be one of the four authored categories")
        elif row_id != category:
            errors.append(f"{prefix}.id must equal its category")
        if isinstance(category, str) and category in CATEGORY_LABELS and row.get("expected_category_label") != CATEGORY_LABELS[category]:
            errors.append(f"{prefix}.expected_category_label must match its category")
        if row.get("surface_fields") != list(SURFACE_FIELDS):
            errors.append(f"{prefix}.surface_fields must cover category, speaker, and text labels")
        for key in ("representative_cue", "expected_behavior", "source_test"):
            if not _text(row.get(key)):
                errors.append(f"{prefix}.{key} must be non-empty text")
        status = row.get("status")
        if not isinstance(status, str) or status not in ITEM_STATUSES:
            errors.append(f"{prefix}.status must remain planned, pending, observed, or issue")
        _references(row.get("evidence"), f"{prefix}.evidence", errors, allow_none=isinstance(status, str) and status in {"planned", "pending"})
    if len(ids) != len(set(ids)):
        errors.append("coverage_rows.id values must be unique")
    if tuple(ids) != CATEGORIES:
        errors.append("coverage_rows must exactly match the frozen category order")
    return errors


def _validate_checks(value: Any) -> list[str]:
    errors: list[str] = []
    if not isinstance(value, list):
        return ["checks must contain exactly six category-coverage checks"]
    if len(value) != len(REQUIRED_CHECKS):
        errors.append("checks must contain exactly six category-coverage checks")
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
        errors.append("checks must exactly match the frozen category-coverage order")
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
    for key in ("source_revision", "contract_source", "presenter_source", "reviewer_required", "open_gate_reason"):
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
    if value.get("surface_fields") != list(SURFACE_FIELDS):
        errors.append("surface_fields must exactly match category, speaker, and text labels")
    errors.extend(_validate_coverage_rows(value.get("coverage_rows")))
    errors.extend(_validate_checks(value.get("checks")))
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
        print("ACCESSIBILITY_CAPTION_CATEGORY_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("ACCESSIBILITY_CAPTION_CATEGORY_READY: human review remains open")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
