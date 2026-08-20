#!/usr/bin/env python3
"""Validate the accessibility contrast/colorblind cue evidence index.

The index records which palette simulations, contrast floors, state roles, and
shape alternatives must be reviewed. It does not calculate CIEDE2000, render
the HUD, or claim that a human found the cues readable.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

SCHEMA = "accessibility_contrast_colorblind_cue_evidence_v1"
OPEN_STATUSES = {"pending", "not_performed", "in_progress", "failed"}
ITEM_STATUSES = {"planned", "pending", "observed", "issue"}
EVIDENCE_KINDS = {"log", "video", "image", "report"}
SHA = re.compile(r"^[0-9a-f]{40,64}$")
PALETTE_IDS = ("none", "deuteranopia", "protanopia", "tritanopia")
TARGET_DEFICIENCIES = {
    "none": "normal",
    "deuteranopia": "deuteranopia",
    "protanopia": "protanopia",
    "tritanopia": "tritanopia",
}
STATE_ROLES = ("nominal", "caution", "danger", "muted")
ALL_ROLES = ("nominal", "caution", "danger", "muted", "primary", "nominal_soft")
CUE_CATEGORIES = ("info", "caution", "danger", "objective", "navigation")
SHAPE_CUES = ("dot", "triangle", "cross", "diamond", "chevron")
REQUIRED_CHECKS = (
    "role_completeness", "authored_defect_record", "deuteranopia_simulation",
    "protanopia_simulation", "tritanopia_simulation", "normal_vision_separation",
    "panel_contrast_floor", "shape_cue_fallback",
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


def _validate_palettes(value: Any) -> list[str]:
    errors: list[str] = []
    if not isinstance(value, list):
        return ["palette_rows must contain exactly four ordered palette rows"]
    if len(value) != len(PALETTE_IDS):
        errors.append("palette_rows must contain exactly four ordered palette rows")
    ids: list[str] = []
    for index, row in enumerate(value):
        prefix = f"palette_rows[{index}]"
        if not isinstance(row, dict):
            errors.append(f"{prefix} must be an object")
            continue
        palette_id = row.get("palette_id")
        if palette_id not in PALETTE_IDS:
            errors.append(f"{prefix}.palette_id must be one of the four palette IDs")
        else:
            ids.append(palette_id)
            if row.get("target_deficiency") != TARGET_DEFICIENCIES[palette_id]:
                errors.append(f"{prefix}.target_deficiency must match the palette ID")
        if row.get("roles") != list(ALL_ROLES):
            errors.append(f"{prefix}.roles must cover all six published palette roles")
        if row.get("state_roles") != list(STATE_ROLES):
            errors.append(f"{prefix}.state_roles must cover the four signal roles")
        if row.get("shape_cue_fallback") is not True:
            errors.append(f"{prefix}.shape_cue_fallback must be true")
        status = row.get("status")
        if not isinstance(status, str) or status not in ITEM_STATUSES:
            errors.append(f"{prefix}.status must remain planned, pending, observed, or issue")
        _references(row.get("evidence"), f"{prefix}.evidence", errors, allow_none=isinstance(status, str) and status in {"planned", "pending"})
    if len(ids) != len(set(ids)):
        errors.append("palette_rows.palette_id values must be unique")
    if tuple(ids) != PALETTE_IDS:
        errors.append("palette_rows must exactly match the frozen palette order")
    return errors


def _validate_checks(value: Any) -> list[str]:
    errors: list[str] = []
    if not isinstance(value, list):
        return ["checks must contain exactly eight contrast/cue checks"]
    if len(value) != len(REQUIRED_CHECKS):
        errors.append("checks must contain exactly eight contrast/cue checks")
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
        errors.append("checks must exactly match the frozen contrast/cue order")
    return errors


def validate_index(value: Any) -> list[str]:
    """Return blocking errors; empty means ready for the still-open visual gate."""
    if not isinstance(value, dict):
        return ["index must be an object"]
    errors: list[str] = []
    if value.get("schema") != SCHEMA:
        errors.append(f"schema must be {SCHEMA}")
    if value.get("human_review_status") not in OPEN_STATUSES:
        errors.append("human_review_status must remain pending, not_performed, in_progress, or failed")
    if value.get("native_render_status") not in {"not_run", "planned", "blocked"}:
        errors.append("native_render_status must remain not_run, planned, or blocked")
    for key in ("source_revision", "palette_source", "reviewer_required", "open_gate_reason"):
        if not _text(value.get(key)):
            errors.append(f"{key} must be non-empty text")
    for key, expected in (
        ("human_review_performed", False),
        ("native_render_performed", False),
        ("detached_contract_tests_only", True),
        ("presentation_only", True),
        ("gameplay_authority", False),
    ):
        if value.get(key) is not expected:
            errors.append(f"{key} must be {str(expected).lower()}")
    if value.get("simulation_method") != "machado_oliveira_fernandes_linear_rgb":
        errors.append("simulation_method must identify the frozen dichromacy method")
    if value.get("delta_e_metric") != "CIEDE2000":
        errors.append("delta_e_metric must be CIEDE2000")
    if value.get("contrast_metric") != "WCAG_2.x":
        errors.append("contrast_metric must be WCAG_2.x")
    if value.get("minimum_state_separation") != 24.0:
        errors.append("minimum_state_separation must be 24.0")
    if value.get("minimum_normal_separation") != 20.0:
        errors.append("minimum_normal_separation must be 20.0")
    if value.get("minimum_panel_contrast") != 4.5:
        errors.append("minimum_panel_contrast must be 4.5")
    if value.get("cue_categories") != list(CUE_CATEGORIES):
        errors.append("cue_categories must exactly match the five HUD cue categories")
    if value.get("shape_cues") != list(SHAPE_CUES):
        errors.append("shape_cues must exactly match the five non-colour alternatives")
    errors.extend(_validate_palettes(value.get("palette_rows")))
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
        print("ACCESSIBILITY_CONTRAST_CUE_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("ACCESSIBILITY_CONTRAST_CUE_READY: human visual review remains open")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
