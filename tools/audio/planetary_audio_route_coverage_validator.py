#!/usr/bin/env python3
"""Validate planetary ambience route/profile coverage without native audition."""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
from typing import Any


SCHEMA = "planetary_audio_route_coverage_v1"
REQUIRED_CONTEXTS = {"exterior", "interior", "cabin"}


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _number(value: Any) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(float(value))


def validate_manifest(manifest: Any) -> list[str]:
    if not isinstance(manifest, dict):
        return ["manifest must be an object"]
    errors: list[str] = []
    if manifest.get("schema") != SCHEMA:
        errors.append(f"schema must be {SCHEMA}")
    for key in ("revision", "world_id", "catalog_evidence", "routing_evidence"):
        if not _text(manifest.get(key)):
            errors.append(f"{key} is required")
    if manifest.get("native_audition") != "OPEN":
        errors.append("native_audition must be OPEN")
    if not _text(manifest.get("boundary_note")):
        errors.append("boundary_note is required")
    if manifest.get("claim") != "AUTOMATED_ROUTE_ONLY":
        errors.append("claim must be AUTOMATED_ROUTE_ONLY")

    profiles = manifest.get("profiles")
    if not isinstance(profiles, list) or not profiles:
        errors.append("profiles must be a non-empty array")
        profiles = []
    contexts: set[str] = set()
    for index, profile in enumerate(profiles):
        prefix = f"profiles[{index}]"
        if not isinstance(profile, dict):
            errors.append(f"{prefix} must be an object")
            continue
        context = profile.get("context")
        if context not in REQUIRED_CONTEXTS:
            errors.append(f"{prefix}.context is invalid")
        elif context in contexts:
            errors.append(f"{prefix}.context is duplicated")
        else:
            contexts.add(context)
        profile_id = profile.get("profile_id")
        if not _text(profile_id):
            errors.append(f"{prefix}.profile_id is required")
        for key in ("asset_path", "selection_evidence"):
            if not _text(profile.get(key)):
                errors.append(f"{prefix}.{key} is required")
        if profile.get("bus") != "Ambience":
            errors.append(f"{prefix}.bus must be Ambience")
        if profile.get("positional") is not False:
            errors.append(f"{prefix}.positional must be false")
        gain = profile.get("base_gain_db")
        if not _number(gain) or gain > 6.0 or gain < -80.0:
            errors.append(f"{prefix}.base_gain_db must be between -80 and 6 dB")
        if profile.get("context_alias") != ("interior" if profile.get("context") == "cabin" else profile.get("context")):
            errors.append(f"{prefix}.context_alias is invalid")
    missing = REQUIRED_CONTEXTS - contexts
    if missing:
        errors.append(f"profiles must cover: {', '.join(sorted(missing))}")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    args = parser.parse_args(argv)
    errors = validate_manifest(json.loads(args.manifest.read_text(encoding="utf-8")))
    if errors:
        print("PLANETARY_AUDIO_ROUTE_COVERAGE_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PLANETARY_AUDIO_ROUTE_COVERAGE_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
