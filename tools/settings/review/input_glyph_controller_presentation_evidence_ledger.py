#!/usr/bin/env python3
"""Validate the input-glyph/controller presentation evidence handoff.

The ledger freezes semantic token families, action coverage, deterministic
fallback text, and device-metadata boundaries.  It is presentation evidence
only: no controller is probed, no InputMap is touched, and no hardware claim
can be promoted by this validator.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

SCHEMA = "input_glyph_controller_presentation_evidence_v1"
OPEN_STATUSES = {"pending", "not_performed", "in_progress", "failed"}
ITEM_STATUSES = {"planned", "pending", "observed", "issue"}
EVIDENCE_KINDS = {"log", "video", "image", "report"}
SHA = re.compile(r"^[0-9a-f]{40,64}$")
FAMILIES = (
    "keyboard", "mouse", "gamepad_generic", "gamepad_xbox",
    "gamepad_playstation", "gamepad_nintendo",
)
TOKEN_PREFIXES = {
    "keyboard": "key.",
    "mouse": "mouse.",
    "gamepad_generic": "gamepad.generic.",
    "gamepad_xbox": "gamepad.xbox.",
    "gamepad_playstation": "gamepad.playstation.",
    "gamepad_nintendo": "gamepad.nintendo.",
}
REQUIRED_ACTIONS = (
    "move_forward", "move_back", "move_left", "move_right", "pitch_up",
    "pitch_down", "roll_left", "roll_right", "jump", "sprint_boost",
    "interact", "hover", "fire", "barrel_roll", "landing_assist",
    "toggle_ship_camera_view", "camera_distance_in", "camera_distance_out",
    "brake", "pause", "toggle_controls_overlay", "toggle_first_person",
)
REQUIRED_CHECKS = (
    "semantic_tokens", "keyboard_physical_keys", "mouse_buttons",
    "gamepad_generic_fallback", "gamepad_xbox_labels",
    "gamepad_playstation_labels", "gamepad_nintendo_labels",
    "unknown_metadata_generic", "deadzone_noise_inert",
    "explicit_family_override", "accessible_text_fallback", "detached_profile_audit",
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


def _validate_families(value: Any) -> list[str]:
    errors: list[str] = []
    if not isinstance(value, list):
        return ["families must contain exactly six semantic glyph families"]
    if len(value) != len(FAMILIES):
        errors.append("families must contain exactly six semantic glyph families")
    ids: list[str] = []
    for index, family in enumerate(value):
        prefix = f"families[{index}]"
        if not isinstance(family, dict):
            errors.append(f"{prefix} must be an object")
            continue
        family_id = family.get("id")
        if family_id not in FAMILIES:
            errors.append(f"{prefix}.id must be one of the six frozen glyph families")
        else:
            ids.append(family_id)
            if family.get("token_prefix") != TOKEN_PREFIXES[family_id]:
                errors.append(f"{prefix}.token_prefix must match the family's semantic token prefix")
        if family.get("fallback_text_required") is not True:
            errors.append(f"{prefix}.fallback_text_required must be true")
        if family.get("status") not in ITEM_STATUSES:
            errors.append(f"{prefix}.status must remain planned, pending, observed, or issue")
        if family_id in {"gamepad_generic", "gamepad_xbox", "gamepad_playstation", "gamepad_nintendo"} and family.get("metadata_only") is not True:
            errors.append(f"{prefix}.metadata_only must be true for gamepad families")
        if family_id in {"keyboard", "mouse"} and family.get("metadata_only") is not False:
            errors.append(f"{prefix}.metadata_only must be false for keyboard and mouse")
        evidence = family.get("evidence")
        status = family.get("status")
        _references(evidence, f"{prefix}.evidence", errors, allow_none=isinstance(status, str) and status in {"planned", "pending"})
    if len(ids) != len(set(ids)):
        errors.append("families.id values must be unique")
    if tuple(ids) != FAMILIES:
        errors.append("families must exactly match the frozen semantic family order")
    return errors


def _validate_checks(value: Any) -> list[str]:
    errors: list[str] = []
    if not isinstance(value, list):
        return ["checks must contain exactly twelve glyph presentation checks"]
    if len(value) != len(REQUIRED_CHECKS):
        errors.append("checks must contain exactly twelve glyph presentation checks")
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
        errors.append("checks must exactly match the frozen glyph presentation order")
    return errors


def validate_ledger(value: Any) -> list[str]:
    """Return blocking errors; empty means ready for external device review."""
    if not isinstance(value, dict):
        return ["ledger must be an object"]
    errors: list[str] = []
    if value.get("schema") != SCHEMA:
        errors.append(f"schema must be {SCHEMA}")
    if value.get("presentation_review_status") not in OPEN_STATUSES:
        errors.append("presentation_review_status must remain pending, not_performed, in_progress, or failed")
    if value.get("hardware_validation_status") not in {"not_run", "planned", "blocked"}:
        errors.append("hardware_validation_status must remain not_run, planned, or blocked")
    for key in ("source_revision", "resolver_source", "reviewer_required", "open_gate_reason"):
        if not _text(value.get(key)):
            errors.append(f"{key} must be non-empty text")
    for key, expected in (
        ("hardware_run_performed", False),
        ("reads_input_map", False),
        ("mutates_input_map", False),
        ("gameplay_authority", False),
        ("text_fallback_required", True),
        ("detached_contract_tests_only", True),
    ):
        if value.get(key) is not expected:
            errors.append(f"{key} must be {str(expected).lower()}")
    if value.get("families_order") != list(FAMILIES):
        errors.append("families_order must exactly match the resolver's six valid families")
    if value.get("covered_actions") != list(REQUIRED_ACTIONS):
        errors.append("covered_actions must exactly match the production gameplay action roster")
    errors.extend(_validate_families(value.get("families")))
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
        print("INPUT_GLYPH_PRESENTATION_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("INPUT_GLYPH_PRESENTATION_READY: hardware validation remains external")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
