#!/usr/bin/env python3
"""Validate controller remap and glyph hardware-review evidence.

This is a review ledger, not a hardware probe. It keeps the physical-device
gate open while requiring the source contract to name keyboard/mouse and the
three physical controller layout families, every action under review, remap
conflict cases, and curve/hold-toggle trials. Detached tests cannot become
native-device evidence by changing a status string.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

SCHEMA = "controller_remap_hardware_evidence_v1"
HARDWARE_STATUSES = {"not_run", "pending", "in_progress", "failed"}
DEVICE_STATUSES = {"planned", "not_run", "in_progress", "failed"}
TRIAL_STATUSES = {"not_run", "pending", "in_progress", "failed", "observed"}
FAMILIES = ("keyboard", "mouse", "gamepad_xbox", "gamepad_playstation", "gamepad_nintendo")
GLYPH_FAMILIES = ("keyboard", "mouse", "gamepad_generic", "gamepad_xbox", "gamepad_playstation", "gamepad_nintendo")
CONFLICT_POLICIES = {"reject", "replace"}
CURVES = {"linear", "squared"}
HOLD_MODES = {"hold", "toggle"}
SHA = re.compile(r"^[0-9a-f]{40,64}$")
REQUIRED_ACTIONS = (
    "move_forward", "move_backward", "move_left", "move_right", "move_up", "move_down",
    "pitch_up", "pitch_down", "roll_left", "roll_right", "yaw_left", "yaw_right",
    "throttle", "brake", "fire_primary", "boost", "hover", "barrel_roll", "interact",
    "camera_cycle", "toggle_controls_overlay", "pause", "landing_assist",
)
REQUIRED_REVIEW_STEPS = (
    "connect_device", "verify_glyph_family", "remap_binding", "reject_conflict",
    "replace_conflict", "curve_hold_toggle", "controller_only_sortie",
)


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _sha(value: Any) -> bool:
    return isinstance(value, str) and bool(SHA.fullmatch(value))


def _list_text(value: Any, path: str, errors: list[str], expected: tuple[str, ...] | None = None) -> list[str]:
    if not isinstance(value, list) or any(not _text(item) for item in value):
        errors.append(f"{path} must be a list of non-empty strings")
        return []
    if len(value) != len(set(value)):
        errors.append(f"{path} must not contain duplicates")
    if expected is not None and tuple(value) != expected:
        errors.append(f"{path} must exactly match the frozen review roster")
    return value


def _references(value: Any, prefix: str, errors: list[str], *, allow_none: bool) -> None:
    if value is None and allow_none:
        return
    if not isinstance(value, list) or not value:
        errors.append(f"{prefix} must be null before a run or a non-empty evidence list")
        return
    seen: set[tuple[str, str]] = set()
    for index, reference in enumerate(value):
        label = f"{prefix}[{index}]"
        if not isinstance(reference, dict):
            errors.append(f"{label} must be an object")
            continue
        if not isinstance(reference.get("kind"), str) or reference.get("kind") not in {"log", "video", "image", "report"}:
            errors.append(f"{label}.kind is unsupported")
        path = reference.get("path")
        digest = reference.get("sha256")
        if not _text(path):
            errors.append(f"{label}.path must be non-empty text")
        if not _sha(digest):
            errors.append(f"{label}.sha256 must be a lowercase digest")
        if isinstance(path, str) and isinstance(digest, str):
            identity = (path, digest)
            if identity in seen:
                errors.append(f"{label} duplicates an earlier reference")
            seen.add(identity)


def _validate_devices(value: Any) -> list[str]:
    errors: list[str] = []
    if not isinstance(value, list) or len(value) != len(FAMILIES):
        return ["device_families must contain exactly keyboard, mouse, and three controller layouts"]
    ids: list[str] = []
    for index, device in enumerate(value):
        prefix = f"device_families[{index}]"
        if not isinstance(device, dict):
            errors.append(f"{prefix} must be an object")
            continue
        family = device.get("family")
        if not isinstance(family, str) or family not in FAMILIES:
            errors.append(f"{prefix}.family must be one of the five physical families")
        else:
            ids.append(family)
        for key in ("name", "connection", "glyph_family"):
            if not _text(device.get(key)):
                errors.append(f"{prefix}.{key} must be non-empty text")
        if family == "keyboard" and device.get("glyph_family") != "keyboard":
            errors.append(f"{prefix}.keyboard glyph_family must be keyboard")
        if family == "mouse" and device.get("glyph_family") != "mouse":
            errors.append(f"{prefix}.mouse glyph_family must be mouse")
        if isinstance(family, str) and family.startswith("gamepad_") and device.get("glyph_family") != family:
            errors.append(f"{prefix}.controller glyph_family must match family")
        if not isinstance(device.get("status"), str) or device.get("status") not in DEVICE_STATUSES:
            errors.append(f"{prefix}.status must remain an open device-review status")
    if tuple(ids) != FAMILIES:
        errors.append("device_families must exactly cover the frozen physical family order")
    return errors


def _validate_glyphs(value: Any) -> list[str]:
    errors: list[str] = []
    if not isinstance(value, dict):
        return ["glyph_review must be an object"]
    if not isinstance(value.get("status"), str) or value.get("status") not in TRIAL_STATUSES:
        errors.append("glyph_review.status must remain open")
    if value.get("hardware_claim") is not False:
        errors.append("glyph_review.hardware_claim must be false before physical review")
    families = _list_text(value.get("required_families"), "glyph_review.required_families", errors, GLYPH_FAMILIES)
    if set(families) != set(GLYPH_FAMILIES):
        errors.append("glyph_review.required_families must cover generic and physical glyph families")
    actions = _list_text(value.get("covered_actions"), "glyph_review.covered_actions", errors, REQUIRED_ACTIONS)
    if set(actions) != set(REQUIRED_ACTIONS):
        errors.append("glyph_review.covered_actions must cover every required action")
    _references(value.get("evidence"), "glyph_review.evidence", errors, allow_none=value.get("status") == "not_run")
    return errors


def _validate_remaps(value: Any) -> list[str]:
    errors: list[str] = []
    if not isinstance(value, list) or not value:
        return ["remap_trials must contain at least one trial"]
    ids: list[str] = []
    for index, trial in enumerate(value):
        prefix = f"remap_trials[{index}]"
        if not isinstance(trial, dict):
            errors.append(f"{prefix} must be an object")
            continue
        trial_id = trial.get("id")
        if not _text(trial_id):
            errors.append(f"{prefix}.id must be non-empty text")
        else:
            ids.append(trial_id)
        if not isinstance(trial.get("device_family"), str) or trial.get("device_family") not in FAMILIES:
            errors.append(f"{prefix}.device_family must name a physical family")
        if not _text(trial.get("action")):
            errors.append(f"{prefix}.action must be non-empty text")
        elif trial["action"] not in REQUIRED_ACTIONS:
            errors.append(f"{prefix}.action is outside the required action roster")
        for key in ("from_binding", "to_binding"):
            if not _text(trial.get(key)):
                errors.append(f"{prefix}.{key} must be non-empty text")
        if not isinstance(trial.get("conflict_policy"), str) or trial.get("conflict_policy") not in CONFLICT_POLICIES:
            errors.append(f"{prefix}.conflict_policy must be reject or replace")
        if not isinstance(trial.get("status"), str) or trial.get("status") not in TRIAL_STATUSES:
            errors.append(f"{prefix}.status must remain open")
        _references(trial.get("evidence"), f"{prefix}.evidence", errors, allow_none=trial.get("status") == "not_run")
    if len(ids) != len(set(ids)):
        errors.append("remap_trials.id values must be unique")
    policies = {trial.get("conflict_policy") for trial in value if isinstance(trial, dict) and isinstance(trial.get("conflict_policy"), str)}
    if policies != CONFLICT_POLICIES:
        errors.append("remap_trials must cover both reject and replace conflict policies")
    return errors


def _validate_curve_trials(value: Any) -> list[str]:
    errors: list[str] = []
    if not isinstance(value, list) or not value:
        return ["curve_hold_trials must contain at least one trial"]
    ids: list[str] = []
    for index, trial in enumerate(value):
        prefix = f"curve_hold_trials[{index}]"
        if not isinstance(trial, dict):
            errors.append(f"{prefix} must be an object")
            continue
        if not _text(trial.get("id")):
            errors.append(f"{prefix}.id must be non-empty text")
        else:
            ids.append(trial["id"])
        if not _text(trial.get("action")) or trial.get("action") not in REQUIRED_ACTIONS:
            errors.append(f"{prefix}.action must be in the required action roster")
        if not isinstance(trial.get("curve"), str) or trial.get("curve") not in CURVES:
            errors.append(f"{prefix}.curve must be linear or squared")
        if not isinstance(trial.get("hold_mode"), str) or trial.get("hold_mode") not in HOLD_MODES:
            errors.append(f"{prefix}.hold_mode must be hold or toggle")
        deadzone = trial.get("deadzone")
        if not isinstance(deadzone, (int, float)) or isinstance(deadzone, bool) or not 0 <= deadzone < 1:
            errors.append(f"{prefix}.deadzone must be a number in [0, 1)")
        if not isinstance(trial.get("status"), str) or trial.get("status") not in TRIAL_STATUSES:
            errors.append(f"{prefix}.status must remain open")
        _references(trial.get("evidence"), f"{prefix}.evidence", errors, allow_none=trial.get("status") == "not_run")
    if len(ids) != len(set(ids)):
        errors.append("curve_hold_trials.id values must be unique")
    return errors


def validate_manifest(value: Any) -> list[str]:
    if not isinstance(value, dict):
        return ["manifest must be an object"]
    errors: list[str] = []
    if value.get("schema") != SCHEMA:
        errors.append(f"schema must be {SCHEMA}")
    if not isinstance(value.get("hardware_test_status"), str) or value.get("hardware_test_status") not in HARDWARE_STATUSES:
        errors.append("hardware_test_status must remain not_run, pending, in_progress, or failed")
    for key in ("source_revision", "reviewer_required", "open_gate_reason"):
        if not _text(value.get(key)):
            errors.append(f"{key} must be non-empty text")
    if value.get("hardware_execution_performed") is not False:
        errors.append("hardware_execution_performed must remain false")
    if value.get("detached_contract_tests_only") is not True:
        errors.append("detached_contract_tests_only must be true")
    _list_text(value.get("review_steps"), "review_steps", errors, REQUIRED_REVIEW_STEPS)
    if value.get("device_families") is not None:
        errors.extend(_validate_devices(value.get("device_families")))
    else:
        errors.append("device_families is required")
    errors.extend(_validate_glyphs(value.get("glyph_review")))
    errors.extend(_validate_remaps(value.get("remap_trials")))
    errors.extend(_validate_curve_trials(value.get("curve_hold_trials")))
    target = value.get("hardware_target")
    if not isinstance(target, dict):
        errors.append("hardware_target must be an object")
    else:
        if target.get("platform") != "Windows":
            errors.append("hardware_target.platform must be Windows")
        if target.get("status") != "not_run":
            errors.append("hardware_target.status must remain not_run")
        _references(target.get("evidence"), "hardware_target.evidence", errors, allow_none=True)
    return errors


def validate(path: str | Path) -> list[str]:
    try:
        value = json.loads(Path(path).read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"manifest unreadable: {exc}"]
    return validate_manifest(value)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    args = parser.parse_args(argv)
    errors = validate(args.manifest)
    if errors:
        print("CONTROLLER_REMAP_HARDWARE_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("CONTROLLER_REMAP_HARDWARE_READY: physical review remains open")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
