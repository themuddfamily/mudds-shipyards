#!/usr/bin/env python3
"""Validate ambience route/attenuation state transitions without audition."""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
from typing import Any


SCHEMA = "audio_ambience_route_state_ledger_v1"
STATES = {"exterior", "interior", "cabin"}
TRANSITIONS = {("exterior", "interior"), ("interior", "exterior"), ("exterior", "cabin"), ("cabin", "exterior")}


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _number(value: Any) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(float(value))


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
    if ledger.get("claim") != "AUTOMATED_ROUTE_STATE_ONLY":
        errors.append("claim must be AUTOMATED_ROUTE_STATE_ONLY")
    if not _text(ledger.get("boundary_note")):
        errors.append("boundary_note is required")

    states = ledger.get("states")
    if not isinstance(states, list) or not states:
        errors.append("states must be a non-empty array")
        states = []
    seen_states: set[str] = set()
    for index, state in enumerate(states):
        prefix = f"states[{index}]"
        if not isinstance(state, dict):
            errors.append(f"{prefix} must be an object")
            continue
        name = state.get("name")
        if name not in STATES:
            errors.append(f"{prefix}.name is invalid")
        elif name in seen_states:
            errors.append(f"{prefix}.name is duplicated")
        else:
            seen_states.add(name)
        if state.get("bus") != "Ambience":
            errors.append(f"{prefix}.bus must be Ambience")
        gain = state.get("gain_db")
        attenuation = state.get("attenuation_db")
        if not _number(gain) or gain < -80 or gain > 6:
            errors.append(f"{prefix}.gain_db must be between -80 and 6 dB")
        if not _number(attenuation) or attenuation > 0 or attenuation < -80:
            errors.append(f"{prefix}.attenuation_db must be between -80 and 0 dB")
        if name == "exterior" and attenuation != 0:
            errors.append(f"{prefix}.exterior attenuation must be 0 dB")
        if name in {"interior", "cabin"} and attenuation == 0:
            errors.append(f"{prefix}.interior attenuation must be below 0 dB")
        if not _text(state.get("evidence")):
            errors.append(f"{prefix}.evidence is required")
    missing_states = STATES - seen_states
    if missing_states:
        errors.append(f"states must cover: {', '.join(sorted(missing_states))}")

    transitions = ledger.get("transitions")
    if not isinstance(transitions, list) or not transitions:
        errors.append("transitions must be a non-empty array")
        transitions = []
    seen_transitions: set[tuple[Any, Any]] = set()
    for index, transition in enumerate(transitions):
        prefix = f"transitions[{index}]"
        if not isinstance(transition, dict):
            errors.append(f"{prefix} must be an object")
            continue
        pair = (transition.get("from"), transition.get("to"))
        if pair in seen_transitions:
            errors.append(f"{prefix}.from/to is duplicated")
        seen_transitions.add(pair)
        if pair not in TRANSITIONS:
            errors.append(f"{prefix}.from/to is invalid")
        fade = transition.get("fade_seconds")
        if not _number(fade) or fade <= 0 or fade > 2:
            errors.append(f"{prefix}.fade_seconds must be greater than 0 and at most 2")
        if not _text(transition.get("evidence")):
            errors.append(f"{prefix}.evidence is required")
        if transition.get("presentation_only") is not True:
            errors.append(f"{prefix}.presentation_only must be true")
    if TRANSITIONS - seen_transitions:
        errors.append("transitions missing required ambience paths")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("ledger", type=Path)
    args = parser.parse_args(argv)
    errors = validate_ledger(json.loads(args.ledger.read_text(encoding="utf-8")))
    if errors:
        print("AUDIO_AMBIENCE_ROUTE_STATE_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("AUDIO_AMBIENCE_ROUTE_STATE_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
