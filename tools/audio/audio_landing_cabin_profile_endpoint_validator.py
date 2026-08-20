#!/usr/bin/env python3
"""Validate landing/cabin ambience profile endpoint evidence without audition."""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
from typing import Any


SCHEMA = "audio_landing_cabin_profile_endpoint_v1"
PROFILES = {"landing_approach", "touchdown", "cabin"}


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _gain(value: Any) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(float(value)) and -80 <= value <= 6


def validate_ledger(ledger: Any) -> list[str]:
    if not isinstance(ledger, dict):
        return ["ledger must be an object"]
    errors: list[str] = []
    if ledger.get("schema") != SCHEMA:
        errors.append(f"schema must be {SCHEMA}")
    for key in ("revision", "owner", "evidence_bundle"):
        if not _text(ledger.get(key)):
            errors.append(f"{key} is required")
    if ledger.get("native_audition") != "OPEN":
        errors.append("native_audition must be OPEN")
    if ledger.get("claim") != "AUTOMATED_ENDPOINT_ONLY":
        errors.append("claim must be AUTOMATED_ENDPOINT_ONLY")
    if not _text(ledger.get("boundary_note")):
        errors.append("boundary_note is required")

    profiles = ledger.get("profiles")
    if not isinstance(profiles, list) or not profiles:
        errors.append("profiles must be a non-empty array")
        profiles = []
    seen: set[str] = set()
    for index, profile in enumerate(profiles):
        prefix = f"profiles[{index}]"
        if not isinstance(profile, dict):
            errors.append(f"{prefix} must be an object")
            continue
        name = profile.get("name")
        if name not in PROFILES:
            errors.append(f"{prefix}.name is invalid")
        elif name in seen:
            errors.append(f"{prefix}.name is duplicated")
        else:
            seen.add(name)
        for key in ("asset_id", "catalog_evidence", "endpoint_evidence"):
            if not _text(profile.get(key)):
                errors.append(f"{prefix}.{key} is required")
        if profile.get("bus") != "Ambience":
            errors.append(f"{prefix}.bus must be Ambience")
        if profile.get("positional") is not False:
            errors.append(f"{prefix}.positional must be false")
        for key in ("entry_gain_db", "steady_gain_db", "exit_gain_db"):
            if not _gain(profile.get(key)):
                errors.append(f"{prefix}.{key} must be between -80 and 6 dB")
        if profile.get("exit_gain_db") != -80:
            errors.append(f"{prefix}.exit_gain_db must be -80 dB stop endpoint")
        if profile.get("entry_gain_db") > profile.get("steady_gain_db") if _gain(profile.get("entry_gain_db")) and _gain(profile.get("steady_gain_db")) else False:
            errors.append(f"{prefix}.entry_gain_db must not exceed steady_gain_db")
    missing = PROFILES - seen
    if missing:
        errors.append(f"profiles must cover: {', '.join(sorted(missing))}")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("ledger", type=Path)
    args = parser.parse_args(argv)
    errors = validate_ledger(json.loads(args.ledger.read_text(encoding="utf-8")))
    if errors:
        print("AUDIO_LANDING_CABIN_ENDPOINT_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("AUDIO_LANDING_CABIN_ENDPOINT_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
