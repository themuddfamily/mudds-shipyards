#!/usr/bin/env python3
"""Validate the accessibility visual-fallback evidence handoff.

The ledger freezes visual accessibility settings, colour-safe cue alternatives,
caption/text fallback, reduced-motion behaviour, and scale/contrast bounds. It
cannot render the HUD or substitute for human accessibility review.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

SCHEMA = "accessibility_visual_fallback_evidence_v1"
OPEN_STATUSES = {"pending", "not_performed", "in_progress", "failed"}
ITEM_STATUSES = {"planned", "pending", "observed", "issue"}
EVIDENCE_KINDS = {"log", "video", "image", "report"}
SHA = re.compile(r"^[0-9a-f]{40,64}$")
SETTING_KEYS = ("reduced_motion", "colorblind_palette", "captions_enabled", "ui_scale")
PALETTES = ("none", "deuteranopia", "protanopia", "tritanopia")
PALETTE_TARGETS = {
    "none": "normal",
    "deuteranopia": "deuteranopia",
    "protanopia": "protanopia",
    "tritanopia": "tritanopia",
}
CUE_CATEGORIES = ("info", "caution", "danger", "objective", "navigation")
SHAPE_CUES = ("dot", "triangle", "cross", "diamond", "chevron")
REQUIRED_CHECKS = (
    "reduced_flash_zero", "reduced_motion_zero", "colour_safe_shape_cue",
    "contrast_floor", "caption_audio_fallback", "caption_key_cue",
    "ui_scale_bounds", "palette_default_fallback", "atomic_profile_rejection",
    "detached_presentation_authority",
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
        return ["palettes must contain exactly four colour-vision presets"]
    if len(value) != len(PALETTES):
        errors.append("palettes must contain exactly four colour-vision presets")
    ids: list[str] = []
    for index, palette in enumerate(value):
        prefix = f"palettes[{index}]"
        if not isinstance(palette, dict):
            errors.append(f"{prefix} must be an object")
            continue
        palette_id = palette.get("id")
        if palette_id not in PALETTES:
            errors.append(f"{prefix}.id must be one of the four frozen palette IDs")
        else:
            ids.append(palette_id)
            if palette.get("target_deficiency") != PALETTE_TARGETS[palette_id]:
                errors.append(f"{prefix}.target_deficiency must match the palette ID")
        if palette.get("fallback_to_authored") is not True:
            errors.append(f"{prefix}.fallback_to_authored must be true")
        status = palette.get("status")
        if not isinstance(status, str) or status not in ITEM_STATUSES:
            errors.append(f"{prefix}.status must remain planned, pending, observed, or issue")
        _references(palette.get("evidence"), f"{prefix}.evidence", errors, allow_none=isinstance(status, str) and status in {"planned", "pending"})
    if len(ids) != len(set(ids)):
        errors.append("palettes.id values must be unique")
    if tuple(ids) != PALETTES:
        errors.append("palettes must exactly match the frozen colour-vision order")
    return errors


def _validate_checks(value: Any) -> list[str]:
    errors: list[str] = []
    if not isinstance(value, list):
        return ["checks must contain exactly ten accessibility fallback checks"]
    if len(value) != len(REQUIRED_CHECKS):
        errors.append("checks must contain exactly ten accessibility fallback checks")
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
        errors.append("checks must exactly match the frozen accessibility fallback order")
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
    for key in ("source_revision", "visual_source", "reviewer_required", "open_gate_reason"):
        if not _text(value.get(key)):
            errors.append(f"{key} must be non-empty text")
    for key, expected in (
        ("human_review_performed", False),
        ("native_render_performed", False),
        ("detached_contract_tests_only", True),
        ("presentation_only", True),
        ("gameplay_authority", False),
        ("audio_authority", False),
        ("caption_authority", False),
    ):
        if value.get(key) is not expected:
            errors.append(f"{key} must be {str(expected).lower()}")
    if value.get("setting_keys") != list(SETTING_KEYS):
        errors.append("setting_keys must exactly match reduced-motion, palette, captions, and UI scale")
    if value.get("cue_categories") != list(CUE_CATEGORIES):
        errors.append("cue_categories must exactly match the five visual cue categories")
    if value.get("shape_cues") != list(SHAPE_CUES):
        errors.append("shape_cues must exactly match the five non-colour cue shapes")
    if value.get("contrast_ratio_minimum") != 4.5:
        errors.append("contrast_ratio_minimum must be 4.5")
    if value.get("large_text_contrast_ratio_minimum") != 3.0:
        errors.append("large_text_contrast_ratio_minimum must be 3.0")
    if value.get("ui_scale_bounds") != {"min": 0.75, "max": 1.6}:
        errors.append("ui_scale_bounds must be min 0.75 and max 1.6")
    errors.extend(_validate_palettes(value.get("palettes")))
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
        print("ACCESSIBILITY_VISUAL_FALLBACK_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("ACCESSIBILITY_VISUAL_FALLBACK_READY: human review remains open")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
