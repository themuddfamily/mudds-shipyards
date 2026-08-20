#!/usr/bin/env python3
"""Validate planetary ambience gain/profile evidence without native audition."""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
from typing import Any


SCHEMA = "planetary_ambience_gain_profile_v1"
REQUIRED_PROFILES = {"temperate_exterior", "temperate_interior"}


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _number(value: Any) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(float(value))


def _gain(value: Any) -> bool:
    return _number(value) and -80.0 <= float(value) <= 6.0


def validate_manifest(manifest: Any) -> list[str]:
    if not isinstance(manifest, dict):
        return ["manifest must be an object"]
    errors: list[str] = []
    if manifest.get("schema") != SCHEMA:
        errors.append(f"schema must be {SCHEMA}")
    for key in ("revision", "world_id", "policy_evidence", "routing_evidence"):
        if not _text(manifest.get(key)):
            errors.append(f"{key} is required")
    if manifest.get("native_audition") != "OPEN":
        errors.append("native_audition must be OPEN")
    if manifest.get("claim") != "AUTOMATED_GAIN_ONLY":
        errors.append("claim must be AUTOMATED_GAIN_ONLY")
    if not _text(manifest.get("boundary_note")):
        errors.append("boundary_note is required")

    profiles = manifest.get("profiles")
    if not isinstance(profiles, list) or not profiles:
        errors.append("profiles must be a non-empty array")
        profiles = []
    seen: set[str] = set()
    for index, profile in enumerate(profiles):
        prefix = f"profiles[{index}]"
        if not isinstance(profile, dict):
            errors.append(f"{prefix} must be an object")
            continue
        profile_id = profile.get("profile_id")
        if profile_id not in REQUIRED_PROFILES:
            errors.append(f"{prefix}.profile_id is invalid")
        elif profile_id in seen:
            errors.append(f"{prefix}.profile_id is duplicated")
        else:
            seen.add(profile_id)
        for key in ("asset_path", "catalog_evidence"):
            if not _text(profile.get(key)):
                errors.append(f"{prefix}.{key} is required")
        for key in ("base_gain_db", "wind_min_gain_db", "wind_max_gain_db", "landing_gain_db"):
            if not _gain(profile.get(key)):
                errors.append(f"{prefix}.{key} must be between -80 and 6 dB")
        if _gain(profile.get("wind_min_gain_db")) and _gain(profile.get("wind_max_gain_db")) and profile["wind_min_gain_db"] > profile["wind_max_gain_db"]:
            errors.append(f"{prefix}.wind_min_gain_db must not exceed wind_max_gain_db")
        attenuation = profile.get("interior_attenuation_db")
        if not _gain(attenuation) or attenuation > 0:
            errors.append(f"{prefix}.interior_attenuation_db must be non-positive and bounded")
        if profile.get("bus") != "Ambience":
            errors.append(f"{prefix}.bus must be Ambience")
        if profile.get("positional") is not False:
            errors.append(f"{prefix}.positional must be false")
    missing = REQUIRED_PROFILES - seen
    if missing:
        errors.append(f"profiles must cover: {', '.join(sorted(missing))}")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    args = parser.parse_args(argv)
    errors = validate_manifest(json.loads(args.manifest.read_text(encoding="utf-8")))
    if errors:
        print("PLANETARY_AMBIENCE_GAIN_PROFILE_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PLANETARY_AMBIENCE_GAIN_PROFILE_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
