#!/usr/bin/env python3
"""Validate authored atmosphere/weather transition evidence."""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
from typing import Any

SCHEMA = "planetary_atmosphere_weather_transition_v1"
PHASES = ("space", "entry_heat", "cloud_layer", "surface")
OPEN = {"pending", "not_performed"}


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def validate_ledger(value: Any, label: str = "ledger") -> list[str]:
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema") != SCHEMA:
        errors.append(f"{label}.schema must be {SCHEMA}")
    for key in ("world_id", "source_revision", "unit_system"):
        if not _text(value.get(key)):
            errors.append(f"{label}.{key} is required")
    phases = value.get("phases")
    if not isinstance(phases, list) or len(phases) != len(PHASES):
        errors.append(f"{label}.phases must contain space, entry_heat, cloud_layer, and surface")
        phases = phases if isinstance(phases, list) else []
    previous_altitude = None
    seen: set[str] = set()
    for index, phase in enumerate(phases):
        prefix = f"{label}.phases[{index}]"
        if not isinstance(phase, dict):
            errors.append(f"{prefix} must be an object")
            continue
        ident = phase.get("id")
        if ident not in PHASES or ident in seen:
            errors.append(f"{prefix}.id must be a unique ordered phase")
        seen.add(ident)
        if ident != PHASES[index] if index < len(PHASES) else True:
            errors.append(f"{prefix}.id is out of order")
        altitude = phase.get("altitude_m")
        if not isinstance(altitude, (int, float)) or isinstance(altitude, bool) or not math.isfinite(altitude) or altitude < 0:
            errors.append(f"{prefix}.altitude_m must be a non-negative finite number")
        elif previous_altitude is not None and altitude > previous_altitude:
            errors.append(f"{prefix}.altitude_m must descend through the transition")
        else:
            previous_altitude = altitude
        if not _text(phase.get("visual_hint")) or not _text(phase.get("audio_hint")):
            errors.append(f"{prefix} requires visual_hint and audio_hint")
        if phase.get("evidence_status") not in OPEN:
            errors.append(f"{prefix}.evidence_status must remain open")
    weather = value.get("weather_profiles")
    if not isinstance(weather, list) or not weather:
        errors.append(f"{label}.weather_profiles must contain authored profiles")
        weather = []
    weather_ids: set[str] = set()
    for index, profile in enumerate(weather):
        prefix = f"{label}.weather_profiles[{index}]"
        if not isinstance(profile, dict):
            errors.append(f"{prefix} must be an object")
            continue
        ident = profile.get("id")
        if not _text(ident) or ident in weather_ids:
            errors.append(f"{prefix}.id must be unique")
        weather_ids.add(ident)
        if not _text(profile.get("kind")) or not _text(profile.get("audio_hint")):
            errors.append(f"{prefix} requires kind and audio_hint")
        if profile.get("simulation") is not False:
            errors.append(f"{prefix}.simulation must be false")
    native = value.get("native_run")
    if not isinstance(native, dict) or native.get("status") != "NOT_RUN" or native.get("evidence") is not None:
        errors.append(f"{label}.native_run must remain NOT_RUN without evidence")
    exclusions = value.get("authority_exclusions")
    required = {"atmosphere_runtime", "weather_simulation", "audio_resolution", "native_run"}
    if not isinstance(exclusions, list) or not required.issubset(set(exclusions)):
        errors.append(f"{label}.authority_exclusions must preserve runtime and native exclusions")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("ledger", type=Path)
    args = parser.parse_args(argv)
    errors = validate_ledger(json.loads(args.ledger.read_text(encoding="utf-8")))
    if errors:
        print("PLANETARY_ATMOSPHERE_WEATHER_TRANSITION_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PLANETARY_ATMOSPHERE_WEATHER_TRANSITION_VALID_OPEN")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
