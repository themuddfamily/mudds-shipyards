#!/usr/bin/env python3
"""Validate production settings coverage evidence.

This is a source/evidence gate, not a claim that a native device or rendered
ultrawide screen has been reviewed.  Every required settings dimension must be
named and carry an explicit status; hardware remains independently gated.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


SCHEMA = "production_settings_coverage_manifest_v1"
STATUSES = {"NOT_RUN", "IN_PROGRESS", "COMPLETE", "BLOCKED"}
HARDWARE_STATUSES = {"NOT_RUN", "PLANNED", "IN_PROGRESS", "PASSED", "FAILED", "BLOCKED"}
REQUIRED_ACTIONS = {
    "move_forward", "move_backward", "move_left", "move_right", "move_up", "move_down",
    "pitch_up", "pitch_down", "roll_left", "roll_right", "yaw_left", "yaw_right",
    "throttle", "brake", "fire_primary", "boost", "hover", "barrel_roll",
    "interact", "camera_cycle", "toggle_controls_overlay", "pause", "landing_assist",
}
REQUIRED_PROMPTS = {"confirm", "cancel", "back", "apply", "reset", "unsaved_changes"}
REQUIRED_ACCESSIBILITY = {"captions", "color_safe", "high_contrast", "reduced_motion", "ui_scale"}
REQUIRED_ASPECTS = {"16:9", "16:10", "21:9"}
REQUIRED_CURVES = {"linear", "squared"}
REQUIRED_MODES = {"hold", "toggle"}


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _status(value: Any, allowed: set[str], path: str, errors: list[str]) -> None:
    if value not in allowed:
        errors.append(f"{path} must be one of {sorted(allowed)}")


def _section(data: dict[str, Any], key: str, errors: list[str]) -> dict[str, Any] | None:
    value = data.get(key)
    if not isinstance(value, dict):
        errors.append(f"{key} must be an object")
        return None
    _status(value.get("status"), STATUSES, f"{key}.status", errors)
    return value


def _required_names(value: Any, required: set[str], path: str, errors: list[str]) -> None:
    if not isinstance(value, list) or any(not _text(item) for item in value):
        errors.append(f"{path} must be a list of non-empty strings")
        return
    names = set(value)
    if len(names) != len(value):
        errors.append(f"{path} must not contain duplicates")
    missing = sorted(required - names)
    if missing:
        errors.append(f"{path} missing required entries: {', '.join(missing)}")


def validate_manifest(data: Any) -> list[str]:
    if not isinstance(data, dict):
        return ["manifest must be an object"]
    errors: list[str] = []
    if data.get("schema") != SCHEMA:
        errors.append(f"schema must be {SCHEMA}")
    source = data.get("source")
    if not isinstance(source, dict):
        errors.append("source must be an object")
    else:
        for key in ("revision", "settings_owner"):
            if not _text(source.get(key)):
                errors.append(f"source.{key} is required")

    roster = _section(data, "action_roster", errors)
    if roster is not None:
        _required_names(roster.get("required_actions"), REQUIRED_ACTIONS,
                        "action_roster.required_actions", errors)
        _required_names(roster.get("covered_actions"), REQUIRED_ACTIONS,
                        "action_roster.covered_actions", errors)
        if roster.get("required_actions") != roster.get("covered_actions"):
            errors.append("action_roster.covered_actions must exactly match required_actions")

    prompts = _section(data, "prompts", errors)
    if prompts is not None:
        _required_names(prompts.get("families"), REQUIRED_PROMPTS, "prompts.families", errors)

    ultrawide = _section(data, "ultrawide", errors)
    if ultrawide is not None:
        _required_names(ultrawide.get("aspect_ratios"), REQUIRED_ASPECTS,
                        "ultrawide.aspect_ratios", errors)
        if not _text(ultrawide.get("safe_area_contract")):
            errors.append("ultrawide.safe_area_contract is required")

    accessibility = _section(data, "accessibility", errors)
    if accessibility is not None:
        _required_names(accessibility.get("presets"), REQUIRED_ACCESSIBILITY,
                        "accessibility.presets", errors)

    remapping = _section(data, "remapping", errors)
    if remapping is not None:
        for key in ("conflict_resolution", "defaults_reset", "ui_focus"):
            if not isinstance(remapping.get(key), bool):
                errors.append(f"remapping.{key} must be a boolean")
        _required_names(remapping.get("actions"), REQUIRED_ACTIONS,
                        "remapping.actions", errors)

    transforms = _section(data, "curve_hold_toggle", errors)
    if transforms is not None:
        _required_names(transforms.get("curves"), REQUIRED_CURVES,
                        "curve_hold_toggle.curves", errors)
        _required_names(transforms.get("modes"), REQUIRED_MODES,
                        "curve_hold_toggle.modes", errors)
        deadzone = transforms.get("deadzone_range")
        if not isinstance(deadzone, list) or len(deadzone) != 2 or any(
                not isinstance(item, (int, float)) or isinstance(item, bool) for item in deadzone):
            errors.append("curve_hold_toggle.deadzone_range must contain two numbers")
        elif not 0 <= deadzone[0] < deadzone[1] <= 1:
            errors.append("curve_hold_toggle.deadzone_range must be ordered within [0, 1]")

    hardware = data.get("hardware")
    if not isinstance(hardware, dict):
        errors.append("hardware must be an object")
    else:
        _status(hardware.get("status"), HARDWARE_STATUSES, "hardware.status", errors)
        if not _text(hardware.get("platform")):
            errors.append("hardware.platform is required")
        evidence = hardware.get("evidence")
        if hardware.get("status") == "PASSED" and not _text(evidence):
            errors.append("hardware.evidence is required when status is PASSED")
        if hardware.get("status") != "PASSED" and evidence is not None:
            errors.append("hardware.evidence must be null unless status is PASSED")
    return errors


def validate(path: str | Path) -> list[str]:
    try:
        data = json.loads(Path(path).read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"manifest unreadable: {exc}"]
    return validate_manifest(data)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    args = parser.parse_args(argv)
    errors = validate(args.manifest)
    if errors:
        for error in errors:
            print(f"PRODUCTION_SETTINGS_COVERAGE_INVALID: {error}")
        return 1
    print(f"PRODUCTION_SETTINGS_COVERAGE_VALID: {args.manifest}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
