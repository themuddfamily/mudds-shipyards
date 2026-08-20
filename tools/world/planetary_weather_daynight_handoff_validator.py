#!/usr/bin/env python3
"""Validate detached planetary weather/day-night production handoff evidence.

The record joins caller-owned weather sampling, spherical day/night lighting,
cloud/fog transition, and interior/exterior presentation seams.  It never owns
a clock, ephemeris, renderer resource, weather simulation, audio bus, or native
execution.
"""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 1
EVIDENCE_SCOPE = "planetary_weather_daynight_handoff"
EVIDENCE_MODE = "detached_presentation_fixture"
REQUIRED_WORLD_ID = "ember_moon"
REQUIRED_WEATHER_POLICY = "game_scale_weather_field_v1"
REQUIRED_LIGHTING_POLICY = "planetary_day_night_lighting_v1"
REQUIRED_STATES = ("direct_daylight", "atmospheric_twilight", "night", "interior")
REQUIRED_TRANSITIONS = ("space", "atmospheric_entry", "surface_exterior", "interior")


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _unit(value: Any) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(float(value)) and 0.0 <= float(value) <= 1.0


def _finite(value: Any) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(float(value))


def _vector(value: Any) -> bool:
    return isinstance(value, list) and len(value) == 3 and all(_finite(item) for item in value)


def _detached_handoff(value: Any, label: str, errors: list[str]) -> None:
    if not isinstance(value, dict):
        errors.append(f"{label} must be an object")
        return
    if value.get("accepted") is not True:
        errors.append(f"{label}.accepted must be true")
    if value.get("runtime_owner") is not None:
        errors.append(f"{label}.runtime_owner must be null")
    if value.get("renderer_applied") is not False:
        errors.append(f"{label}.renderer_applied must be false")
    if not _text(value.get("evidence_ref")) or not value["evidence_ref"].startswith("res://"):
        errors.append(f"{label}.evidence_ref must be a res:// path")


def validate_handoff(value: Any, label: str = "handoff") -> list[str]:
    """Return blocking errors for one detached weather/day-night handoff."""

    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    if value.get("evidence_scope") != EVIDENCE_SCOPE:
        errors.append(f"{label}.evidence_scope must be {EVIDENCE_SCOPE}")
    if value.get("evidence_mode") != EVIDENCE_MODE:
        errors.append(f"{label}.evidence_mode must be {EVIDENCE_MODE}")
    for key in ("production_wiring", "native_claims", "weather_clock_owner", "ephemeris_owner", "renderer_application"):
        if value.get(key) is not False:
            errors.append(f"{label}.{key} must be false")
    if value.get("world_id") != REQUIRED_WORLD_ID:
        errors.append(f"{label}.world_id must be {REQUIRED_WORLD_ID}")
    if not _text(value.get("source_revision")):
        errors.append(f"{label}.source_revision is required")

    weather = value.get("weather")
    if not isinstance(weather, dict):
        errors.append(f"{label}.weather must be an object")
    else:
        if weather.get("policy_version") != REQUIRED_WEATHER_POLICY:
            errors.append(f"{label}.weather.policy_version must be {REQUIRED_WEATHER_POLICY}")
        if weather.get("caller_time_only") is not True:
            errors.append(f"{label}.weather.caller_time_only must be true")
        if weather.get("cloud_layer_top_exclusive") is not True:
            errors.append(f"{label}.weather.cloud_layer_top_exclusive must be true")
        if weather.get("fog_clamped") is not True:
            errors.append(f"{label}.weather.fog_clamped must be true")
        for key in ("cloud_coverage_unitless", "weather_intensity_unitless", "fog_factor_unitless", "gust_factor_unitless"):
            if not _unit(weather.get(key)):
                errors.append(f"{label}.weather.{key} must be a bounded unit value")
        if not _vector(weather.get("wind_velocity_mps")):
            errors.append(f"{label}.weather.wind_velocity_mps must be a finite vector")
        if not _text(weather.get("evidence_ref")) or not weather["evidence_ref"].startswith("res://"):
            errors.append(f"{label}.weather.evidence_ref must be a res:// path")

    lighting = value.get("lighting")
    if not isinstance(lighting, dict):
        errors.append(f"{label}.lighting must be an object")
    else:
        if lighting.get("policy_version") != REQUIRED_LIGHTING_POLICY:
            errors.append(f"{label}.lighting.policy_version must be {REQUIRED_LIGHTING_POLICY}")
        if lighting.get("observation_frame") != "planetary_body_local":
            errors.append(f"{label}.lighting.observation_frame must be planetary_body_local")
        if lighting.get("caller_clock_only") is not True:
            errors.append(f"{label}.lighting.caller_clock_only must be true")
        twilight = lighting.get("twilight_min_clearance_degrees")
        if not _finite(twilight) or not -18.0 <= float(twilight) <= -0.001:
            errors.append(f"{label}.lighting.twilight_min_clearance_degrees must be bounded")
        if not _unit(lighting.get("moonlight_energy_factor_unitless")):
            errors.append(f"{label}.lighting.moonlight_energy_factor_unitless must be bounded")
        if tuple(lighting.get("states", [])) != REQUIRED_STATES:
            errors.append(f"{label}.lighting.states must contain the four authored presentation states")
        if not _text(lighting.get("evidence_ref")) or not lighting["evidence_ref"].startswith("res://"):
            errors.append(f"{label}.lighting.evidence_ref must be a res:// path")

    for key in ("weather_to_clouds", "weather_to_fog", "lighting_to_sun_moon", "interior_exterior_audio"):
        _detached_handoff(value.get(key), f"{label}.{key}", errors)

    transitions = value.get("transitions")
    if not isinstance(transitions, list):
        errors.append(f"{label}.transitions must be an array")
    else:
        transition_ids: list[str] = []
        for index, transition in enumerate(transitions):
            prefix = f"{label}.transitions[{index}]"
            if not isinstance(transition, dict):
                errors.append(f"{prefix} must be an object")
                continue
            transition_id = transition.get("id")
            if not _text(transition_id):
                errors.append(f"{prefix}.id is required")
            elif transition_id in transition_ids:
                errors.append(f"{prefix}.id must be unique")
            transition_ids.append(transition_id)
            if not _unit(transition.get("atmosphere_factor_unitless")):
                errors.append(f"{prefix}.atmosphere_factor_unitless must be bounded")
            if not _unit(transition.get("cloud_factor_unitless")):
                errors.append(f"{prefix}.cloud_factor_unitless must be bounded")
            if transition.get("interior_direct_sources_suppressed") is not (transition_id == "interior"):
                errors.append(f"{prefix}.interior_direct_sources_suppressed is inconsistent with transition ID")
        if tuple(transition_ids) != REQUIRED_TRANSITIONS:
            errors.append(f"{label}.transitions must contain the authored space-to-interior sequence")

    authority = value.get("authority")
    if not isinstance(authority, dict):
        errors.append(f"{label}.authority must be an object")
    else:
        for key in ("clock", "ephemeris", "weather_simulation", "renderer", "audio", "gameplay", "save", "network", "physics"):
            if authority.get(key) is not False:
                errors.append(f"{label}.authority.{key} must be false")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("handoff", type=Path)
    args = parser.parse_args(argv)
    try:
        report = json.loads(args.handoff.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        print(f"PLANETARY_WEATHER_DAYNIGHT_INVALID: {exc}")
        return 1
    errors = validate_handoff(report)
    if errors:
        print("PLANETARY_WEATHER_DAYNIGHT_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PLANETARY_WEATHER_DAYNIGHT_VALID: detached presentation evidence only")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
