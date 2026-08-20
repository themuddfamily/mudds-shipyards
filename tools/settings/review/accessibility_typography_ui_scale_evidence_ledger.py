#!/usr/bin/env python3
"""Validate the accessibility typography/UI-scale evidence handoff.

This ledger freezes the caption presenter's text roles, scale range, safe-area
geometry, wrapping ceiling, and reduced-motion typography policy. It records a
review plan only; it cannot render a viewport or claim human readability.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

SCHEMA = "accessibility_typography_ui_scale_evidence_v1"
OPEN_STATUSES = {"pending", "not_performed", "in_progress", "failed"}
ITEM_STATUSES = {"planned", "pending", "observed", "issue"}
EVIDENCE_KINDS = {"log", "video", "image", "report"}
SHA = re.compile(r"^[0-9a-f]{40,64}$")
SETTING_KEYS = ("ui_scale", "captions_enabled", "reduced_motion")
TYPOGRAPHY_ROLES = ("category", "speaker", "body")
BASE_FONT_SIZES = {"category": 15, "speaker": 18, "body": 22}
REQUIRED_CHECKS = (
    "scale_bounds", "scaled_font_sizes", "text_wrap_512", "safe_area_margins",
    "host_bottom_margin", "contrast_floor", "reduced_flash_no_animation",
    "input_transparent",
)
LAYOUT_CONTRACT = {
    "minimum_ui_scale": 0.75,
    "maximum_ui_scale": 1.6,
    "default_ui_scale": 1.0,
    "base_minimum_panel_width": 560.0,
    "base_maximum_panel_width": 960.0,
    "base_minimum_panel_height": 104.0,
    "base_safe_margin_x": 32.0,
    "base_safe_margin_top": 24.0,
    "base_safe_margin_bottom": 42.0,
    "maximum_text_characters": 512,
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


def _validate_roles(value: Any) -> list[str]:
    errors: list[str] = []
    if not isinstance(value, list):
        return ["typography_roles must contain exactly category, speaker, and body"]
    if len(value) != len(TYPOGRAPHY_ROLES):
        errors.append("typography_roles must contain exactly category, speaker, and body")
    ids: list[str] = []
    for index, role in enumerate(value):
        prefix = f"typography_roles[{index}]"
        if not isinstance(role, dict):
            errors.append(f"{prefix} must be an object")
            continue
        role_id = role.get("id")
        if role_id not in TYPOGRAPHY_ROLES:
            errors.append(f"{prefix}.id must be one of the three frozen text roles")
        else:
            ids.append(role_id)
            if role.get("base_font_size") != BASE_FONT_SIZES[role_id]:
                errors.append(f"{prefix}.base_font_size must match the frozen presenter size")
        if role.get("textual") is not True:
            errors.append(f"{prefix}.textual must be true")
        if role.get("contrast_ratio_minimum") != 7.0:
            errors.append(f"{prefix}.contrast_ratio_minimum must be 7.0")
        status = role.get("status")
        if not isinstance(status, str) or status not in ITEM_STATUSES:
            errors.append(f"{prefix}.status must remain planned, pending, observed, or issue")
        _references(role.get("evidence"), f"{prefix}.evidence", errors, allow_none=isinstance(status, str) and status in {"planned", "pending"})
    if len(ids) != len(set(ids)):
        errors.append("typography_roles.id values must be unique")
    if tuple(ids) != TYPOGRAPHY_ROLES:
        errors.append("typography_roles must exactly match the frozen role order")
    return errors


def _validate_checks(value: Any) -> list[str]:
    errors: list[str] = []
    if not isinstance(value, list):
        return ["checks must contain exactly eight typography/layout checks"]
    if len(value) != len(REQUIRED_CHECKS):
        errors.append("checks must contain exactly eight typography/layout checks")
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
        errors.append("checks must exactly match the frozen typography/layout order")
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
    for key in ("source_revision", "presenter_source", "reviewer_required", "open_gate_reason"):
        if not _text(value.get(key)):
            errors.append(f"{key} must be non-empty text")
    for key, expected in (
        ("human_review_performed", False),
        ("native_render_performed", False),
        ("detached_contract_tests_only", True),
        ("presentation_only", True),
        ("audio_authority", False),
        ("gameplay_authority", False),
    ):
        if value.get(key) is not expected:
            errors.append(f"{key} must be {str(expected).lower()}")
    if value.get("setting_keys") != list(SETTING_KEYS):
        errors.append("setting_keys must exactly match UI scale, captions, and reduced motion")
    if value.get("layout_contract") != LAYOUT_CONTRACT:
        errors.append("layout_contract must exactly match the frozen caption presenter bounds")
    if value.get("safe_area_anchoring") is not True:
        errors.append("safe_area_anchoring must be true")
    if value.get("wraps_text") is not True:
        errors.append("wraps_text must be true")
    if value.get("reduced_flash_policy") != "steady_no_animation":
        errors.append("reduced_flash_policy must be steady_no_animation")
    errors.extend(_validate_roles(value.get("typography_roles")))
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
        print("ACCESSIBILITY_TYPOGRAPHY_SCALE_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("ACCESSIBILITY_TYPOGRAPHY_SCALE_READY: human review remains open")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
