#!/usr/bin/env python3
"""Validate dynamic audio-mix state/transition evidence without audition claims."""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
from typing import Any


SCHEMA = "dynamic_mix_state_evidence_v1"
REQUIRED_STATES = {"station", "encounter", "landing", "destruction"}
REQUIRED_BUSES = {"Music", "SFX", "Ambience", "UI"}


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
    for key in ("revision", "mix_owner", "evidence_bundle"):
        if not _text(manifest.get(key)):
            errors.append(f"{key} is required")
    if manifest.get("audition_status") != "OPEN":
        errors.append("audition_status must be OPEN until human audition is recorded")
    if not _text(manifest.get("audition_boundary")):
        errors.append("audition_boundary is required")
    if manifest.get("claim") != "AUTOMATED_MIX_ONLY":
        errors.append("claim must be AUTOMATED_MIX_ONLY")

    states = manifest.get("states")
    if not isinstance(states, list) or not states:
        errors.append("states must be a non-empty array")
        states = []
    seen: set[str] = set()
    for index, state in enumerate(states):
        prefix = f"states[{index}]"
        if not isinstance(state, dict):
            errors.append(f"{prefix} must be an object")
            continue
        name = state.get("name")
        if name not in REQUIRED_STATES:
            errors.append(f"{prefix}.name is invalid")
        elif name in seen:
            errors.append(f"{prefix}.name is duplicated")
        else:
            seen.add(name)
        if not _text(state.get("evidence")):
            errors.append(f"{prefix}.evidence is required")
        gains = state.get("bus_gains_db")
        if not isinstance(gains, dict):
            errors.append(f"{prefix}.bus_gains_db must be an object")
            gains = {}
        missing = REQUIRED_BUSES - set(gains)
        if missing:
            errors.append(f"{prefix}.bus_gains_db missing {', '.join(sorted(missing))}")
        for bus, gain in gains.items():
            if bus not in REQUIRED_BUSES:
                errors.append(f"{prefix}.bus_gains_db.{bus} is not a supported bus")
            elif not _number(gain) or gain > 6.0 or gain < -80.0:
                errors.append(f"{prefix}.bus_gains_db.{bus} must be between -80 and 6 dB")
    missing = REQUIRED_STATES - seen
    if missing:
        errors.append(f"states must cover: {', '.join(sorted(missing))}")

    transitions = manifest.get("transitions")
    if not isinstance(transitions, list) or not transitions:
        errors.append("transitions must be a non-empty array")
        transitions = []
    for index, transition in enumerate(transitions):
        prefix = f"transitions[{index}]"
        if not isinstance(transition, dict):
            errors.append(f"{prefix} must be an object")
            continue
        for key in ("from", "to", "trigger", "evidence"):
            if not _text(transition.get(key)):
                errors.append(f"{prefix}.{key} is required")
        fade = transition.get("fade_seconds")
        if not _number(fade) or fade < 0 or fade > 10:
            errors.append(f"{prefix}.fade_seconds must be between 0 and 10")
        if transition.get("presentation_only") is not True:
            errors.append(f"{prefix}.presentation_only must be true")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    args = parser.parse_args(argv)
    errors = validate_manifest(json.loads(args.manifest.read_text(encoding="utf-8")))
    if errors:
        print("DYNAMIC_MIX_STATE_EVIDENCE_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("DYNAMIC_MIX_STATE_EVIDENCE_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
