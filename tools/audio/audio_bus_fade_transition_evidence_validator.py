#!/usr/bin/env python3
"""Validate audio bus gain/fade transition evidence without native audition."""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
from typing import Any


SCHEMA = "audio_bus_fade_transition_evidence_v1"
BUSES = {"Music", "SFX", "Ambience", "UI"}


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _number(value: Any) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(float(value))


def validate_record(record: Any) -> list[str]:
    if not isinstance(record, dict):
        return ["record must be an object"]
    errors: list[str] = []
    if record.get("schema") != SCHEMA:
        errors.append(f"schema must be {SCHEMA}")
    for key in ("revision", "mix_owner", "evidence_bundle"):
        if not _text(record.get(key)):
            errors.append(f"{key} is required")
    if record.get("native_audition") != "OPEN":
        errors.append("native_audition must be OPEN")
    if not _text(record.get("boundary_note")):
        errors.append("boundary_note is required")
    if record.get("claim") != "AUTOMATED_FADE_ONLY":
        errors.append("claim must be AUTOMATED_FADE_ONLY")

    transitions = record.get("transitions")
    if not isinstance(transitions, list) or not transitions:
        errors.append("transitions must be a non-empty array")
        transitions = []
    seen: set[tuple[Any, Any, Any]] = set()
    for index, transition in enumerate(transitions):
        prefix = f"transitions[{index}]"
        if not isinstance(transition, dict):
            errors.append(f"{prefix} must be an object")
            continue
        key = (transition.get("from"), transition.get("to"), transition.get("bus"))
        if key in seen:
            errors.append(f"{prefix} is duplicated")
        seen.add(key)
        if not _text(transition.get("from")) or not _text(transition.get("to")):
            errors.append(f"{prefix}.from and to are required")
        bus = transition.get("bus")
        if bus not in BUSES:
            errors.append(f"{prefix}.bus is invalid")
        for key_name in ("from_gain_db", "to_gain_db"):
            gain = transition.get(key_name)
            if not _number(gain) or gain < -80.0 or gain > 6.0:
                errors.append(f"{prefix}.{key_name} must be between -80 and 6 dB")
        fade = transition.get("fade_seconds")
        if not _number(fade) or fade <= 0 or fade > 10:
            errors.append(f"{prefix}.fade_seconds must be greater than 0 and at most 10")
        if not _text(transition.get("evidence")):
            errors.append(f"{prefix}.evidence is required")
        if transition.get("presentation_only") is not True:
            errors.append(f"{prefix}.presentation_only must be true")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("record", type=Path)
    args = parser.parse_args(argv)
    errors = validate_record(json.loads(args.record.read_text(encoding="utf-8")))
    if errors:
        print("AUDIO_BUS_FADE_TRANSITION_EVIDENCE_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("AUDIO_BUS_FADE_TRANSITION_EVIDENCE_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
