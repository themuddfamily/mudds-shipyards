"""Validate the evidence handoff for real controller hardware testing.

This is intentionally a manifest validator, not a hardware probe.  A source
checkout can prove that every required trial has an owner and an explicit
status; only a real device run may change ``hardware_test_status`` to
``passed``.
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any


SCHEMA = "controller_hardware_validation_manifest_v1"
STATUSES = {"not_run", "pending", "passed", "failed", "blocked"}
TRIAL_STATUSES = {"pending", "passed", "failed", "blocked", "not_run"}
DEVICE_STATUSES = {"planned", "tested", "failed", "blocked"}
CURVES = {"linear", "squared"}
MODES = {"hold", "toggle"}


def _required(mapping: dict[str, Any], key: str, path: str, errors: list[str]) -> Any:
    if key not in mapping:
        errors.append(f"{path}.{key} is required")
        return None
    return mapping[key]


def _nonempty(value: Any, path: str, errors: list[str]) -> None:
    if not isinstance(value, str) or not value.strip():
        errors.append(f"{path} must be a non-empty string")


def _status(value: Any, allowed: set[str], path: str, errors: list[str]) -> None:
    if value not in allowed:
        errors.append(f"{path} must be one of {sorted(allowed)}")


def validate(path: str | Path) -> list[str]:
    """Return structural/evidence errors for a controller hardware manifest."""
    manifest_path = Path(path)
    try:
        data = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"cannot read manifest: {exc}"]
    errors: list[str] = []
    if not isinstance(data, dict):
        return ["manifest root must be an object"]
    if data.get("schema") != SCHEMA:
        errors.append(f"schema must be {SCHEMA!r}")
    _status(_required(data, "hardware_test_status", "manifest", errors), STATUSES,
            "hardware_test_status", errors)
    _nonempty(_required(data, "platform", "manifest", errors), "platform", errors)
    devices = _required(data, "device_families", "manifest", errors)
    glyphs = _required(data, "glyphs", "manifest", errors)
    remaps = _required(data, "remap_trials", "manifest", errors)
    curve_trials = _required(data, "curve_hold_trials", "manifest", errors)
    if not isinstance(devices, list) or not devices:
        errors.append("device_families must contain at least one device family")
    else:
        ids: set[str] = set()
        for index, device in enumerate(devices):
            prefix = f"device_families[{index}]"
            if not isinstance(device, dict):
                errors.append(f"{prefix} must be an object")
                continue
            device_id = _required(device, "id", prefix, errors)
            _nonempty(device_id, f"{prefix}.id", errors)
            if isinstance(device_id, str) and device_id in ids:
                errors.append(f"{prefix}.id duplicates {device_id!r}")
            if isinstance(device_id, str):
                ids.add(device_id)
            for field in ("name", "connection", "glyph_set"):
                _nonempty(_required(device, field, prefix, errors), f"{prefix}.{field}", errors)
            _status(_required(device, "status", prefix, errors), DEVICE_STATUSES,
                    f"{prefix}.status", errors)
    if not isinstance(glyphs, dict):
        errors.append("glyphs must be an object")
    else:
        _status(_required(glyphs, "status", "glyphs", errors), TRIAL_STATUSES,
                "glyphs.status", errors)
        actions = _required(glyphs, "required_actions", "glyphs", errors)
        if not isinstance(actions, list) or not actions or any(
                not isinstance(action, str) or not action.strip() for action in actions):
            errors.append("glyphs.required_actions must contain non-empty action names")
        sets = _required(glyphs, "covered_sets", "glyphs", errors)
        if not isinstance(sets, list) or not sets or any(
                not isinstance(value, str) or not value.strip() for value in sets):
            errors.append("glyphs.covered_sets must contain at least one set name")
    for field, values in (("remap_trials", remaps), ("curve_hold_trials", curve_trials)):
        if not isinstance(values, list) or not values:
            errors.append(f"{field} must contain at least one trial")
            continue
        for index, trial in enumerate(values):
            prefix = f"{field}[{index}]"
            if not isinstance(trial, dict):
                errors.append(f"{prefix} must be an object")
                continue
            _nonempty(_required(trial, "id", prefix, errors), f"{prefix}.id", errors)
            _nonempty(_required(trial, "action", prefix, errors), f"{prefix}.action", errors)
            _status(_required(trial, "status", prefix, errors), TRIAL_STATUSES,
                    f"{prefix}.status", errors)
            if field == "remap_trials":
                for key in ("from_binding", "to_binding", "conflict_result"):
                    _nonempty(_required(trial, key, prefix, errors), f"{prefix}.{key}", errors)
            else:
                _status(_required(trial, "curve", prefix, errors), CURVES,
                        f"{prefix}.curve", errors)
                _status(_required(trial, "mode", prefix, errors), MODES,
                        f"{prefix}.mode", errors)
                deadzone = _required(trial, "deadzone", prefix, errors)
                if not isinstance(deadzone, (int, float)) or not 0 <= deadzone < 1:
                    errors.append(f"{prefix}.deadzone must be a number in [0, 1)")
    return errors


def main() -> int:
    import argparse

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    args = parser.parse_args()
    errors = validate(args.manifest)
    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        return 1
    print("controller hardware validation manifest: valid")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
