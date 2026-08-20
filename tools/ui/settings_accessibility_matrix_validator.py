#!/usr/bin/env python3
"""Validate the cross-feature settings/accessibility acceptance matrix.

This is an evidence-shape gate.  It checks that every production-facing
dimension is named, has an explicit status, and points at its focused
contract.  It deliberately does not infer native hardware or human-listening
success from source files.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


SCHEMA = "settings_accessibility_matrix_v1"
STATUSES = {"NOT_RUN", "IN_PROGRESS", "COMPLETE", "BLOCKED"}
HARDWARE_STATUSES = {"NOT_RUN", "PLANNED", "IN_PROGRESS", "PASSED", "FAILED", "BLOCKED"}

REQUIRED_ACTIONS = {
    "move_forward", "move_backward", "move_left", "move_right", "move_up", "move_down",
    "pitch_up", "pitch_down", "roll_left", "roll_right", "yaw_left", "yaw_right",
    "throttle", "brake", "fire_primary", "boost", "hover", "barrel_roll", "interact",
    "camera_cycle", "toggle_controls_overlay", "pause", "landing_assist",
}
REQUIRED_GLYPH_FAMILIES = {
    "keyboard", "mouse", "gamepad_generic", "gamepad_xbox", "gamepad_playstation",
    "gamepad_nintendo", "unknown_fallback",
}
REQUIRED_ASPECTS = {"16:9", "16:10", "21:9", "32:9"}
REQUIRED_VISUAL = {"captions", "colour_safe", "high_contrast", "reduced_flash", "reduced_motion", "ui_scale"}
REQUIRED_AUDIO = {"master", "music", "effects", "voice", "ui"}
REQUIRED_SUBTITLES = {"off", "captions", "captions_and_visual"}
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
    evidence = value.get("evidence")
    if not isinstance(evidence, list) or not evidence or any(not _text(item) for item in evidence):
        errors.append(f"{key}.evidence must be a non-empty list of paths")
    return value


def _names(value: Any, required: set[str], path: str, errors: list[str]) -> None:
    if not isinstance(value, list) or any(not _text(item) for item in value):
        errors.append(f"{path} must be a list of non-empty strings")
        return
    if len(set(value)) != len(value):
        errors.append(f"{path} must not contain duplicates")
    missing = sorted(required - set(value))
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

    actions = _section(data, "action_roster", errors)
    if actions is not None:
        _names(actions.get("required"), REQUIRED_ACTIONS, "action_roster.required", errors)
        _names(actions.get("covered"), REQUIRED_ACTIONS, "action_roster.covered", errors)
        if actions.get("required") != actions.get("covered"):
            errors.append("action_roster.covered must exactly match action_roster.required")

    glyphs = _section(data, "glyphs", errors)
    if glyphs is not None:
        _names(glyphs.get("families"), REQUIRED_GLYPH_FAMILIES, "glyphs.families", errors)
        if glyphs.get("fallback") != "input.unknown":
            errors.append("glyphs.fallback must be input.unknown")

    ultrawide = _section(data, "ultrawide", errors)
    if ultrawide is not None:
        _names(ultrawide.get("aspect_ratios"), REQUIRED_ASPECTS, "ultrawide.aspect_ratios", errors)
        if not _text(ultrawide.get("safe_area_contract")):
            errors.append("ultrawide.safe_area_contract is required")

    visual = _section(data, "visual", errors)
    if visual is not None:
        _names(visual.get("presets"), REQUIRED_VISUAL, "visual.presets", errors)

    audio = _section(data, "audio", errors)
    if audio is not None:
        _names(audio.get("groups"), REQUIRED_AUDIO, "audio.groups", errors)

    subtitles = _section(data, "subtitles", errors)
    if subtitles is not None:
        _names(subtitles.get("modes"), REQUIRED_SUBTITLES, "subtitles.modes", errors)

    remapping = _section(data, "remapping", errors)
    if remapping is not None:
        _names(remapping.get("actions"), REQUIRED_ACTIONS, "remapping.actions", errors)
        for key in ("conflict_resolution", "defaults_reset", "ui_focus"):
            if not isinstance(remapping.get(key), bool):
                errors.append(f"remapping.{key} must be a boolean")
        _names(remapping.get("curves"), REQUIRED_CURVES, "remapping.curves", errors)
        _names(remapping.get("modes"), REQUIRED_MODES, "remapping.modes", errors)
        deadzone = remapping.get("deadzone_range")
        if (not isinstance(deadzone, list) or len(deadzone) != 2 or
                any(not isinstance(v, (int, float)) or isinstance(v, bool) for v in deadzone)):
            errors.append("remapping.deadzone_range must contain two numbers")
        elif not 0 <= deadzone[0] < deadzone[1] <= 1:
            errors.append("remapping.deadzone_range must be ordered within [0, 1]")

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
        return validate_manifest(json.loads(Path(path).read_text(encoding="utf-8")))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"manifest unreadable: {exc}"]


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    args = parser.parse_args(argv)
    errors = validate(args.manifest)
    if errors:
        for error in errors:
            print(f"SETTINGS_ACCESSIBILITY_MATRIX_INVALID: {error}")
        return 1
    print(f"SETTINGS_ACCESSIBILITY_MATRIX_VALID: {args.manifest}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
