#!/usr/bin/env python3
"""Validate combat/station audio routing evidence and authority boundaries."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


SCHEMA = "combat_station_routing_evidence_v1"
REQUIRED_FAMILIES = {"station_music", "station_machinery", "combat_cues", "planetary_surface"}
BUSES = {"Music", "SFX", "Ambience", "UI"}


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def validate_rollup(rollup: Any) -> list[str]:
    if not isinstance(rollup, dict):
        return ["rollup must be an object"]
    errors: list[str] = []
    if rollup.get("schema") != SCHEMA:
        errors.append(f"schema must be {SCHEMA}")
    for key in ("revision", "routing_owner", "evidence_bundle"):
        if not _text(rollup.get(key)):
            errors.append(f"{key} is required")
    if rollup.get("native_audition") != "OPEN":
        errors.append("native_audition must be OPEN")
    if not _text(rollup.get("boundary_note")):
        errors.append("boundary_note is required")
    if rollup.get("claim") != "AUTOMATED_ROUTING_ONLY":
        errors.append("claim must be AUTOMATED_ROUTING_ONLY")

    routes = rollup.get("routes")
    if not isinstance(routes, list) or not routes:
        errors.append("routes must be a non-empty array")
        routes = []
    seen: set[str] = set()
    for index, route in enumerate(routes):
        prefix = f"routes[{index}]"
        if not isinstance(route, dict):
            errors.append(f"{prefix} must be an object")
            continue
        family = route.get("family")
        if family not in REQUIRED_FAMILIES:
            errors.append(f"{prefix}.family is invalid")
        elif family in seen:
            errors.append(f"{prefix}.family is duplicated")
        else:
            seen.add(family)
        if route.get("bus") not in BUSES:
            errors.append(f"{prefix}.bus is invalid")
        expected = {"station_music": "Music", "station_machinery": "Ambience", "combat_cues": "SFX", "planetary_surface": "Ambience"}.get(family)
        if expected and route.get("bus") != expected:
            errors.append(f"{prefix}.bus must be {expected} for {family}")
        for key in ("source_seam", "route_evidence"):
            if not _text(route.get(key)):
                errors.append(f"{prefix}.{key} is required")
        if route.get("presentation_only") is not True:
            errors.append(f"{prefix}.presentation_only must be true")
        exclusions = route.get("authority_exclusions")
        if not isinstance(exclusions, list) or any(not _text(item) for item in exclusions):
            errors.append(f"{prefix}.authority_exclusions must be a list of strings")
        elif "gameplay_damage" not in exclusions or "gameplay_phase" not in exclusions:
            errors.append(f"{prefix}.authority_exclusions must include gameplay_damage and gameplay_phase")
    missing = REQUIRED_FAMILIES - seen
    if missing:
        errors.append(f"routes must cover: {', '.join(sorted(missing))}")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("rollup", type=Path)
    args = parser.parse_args(argv)
    errors = validate_rollup(json.loads(args.rollup.read_text(encoding="utf-8")))
    if errors:
        print("COMBAT_STATION_ROUTING_EVIDENCE_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("COMBAT_STATION_ROUTING_EVIDENCE_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
