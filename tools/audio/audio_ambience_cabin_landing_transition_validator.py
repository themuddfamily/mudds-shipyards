#!/usr/bin/env python3
"""Validate cabin/landing ambience transition evidence without audition."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


SCHEMA = "audio_ambience_cabin_landing_transition_v1"
STATES = {"cabin", "landing_approach", "touchdown"}
PATHS = {("cabin", "landing_approach"), ("landing_approach", "touchdown"), ("touchdown", "cabin"), ("landing_approach", "cabin")}
ACTIONS = {"start", "stop", "fade_in", "fade_out", "retain"}


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


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
    if ledger.get("claim") != "AUTOMATED_CABIN_LANDING_ONLY":
        errors.append("claim must be AUTOMATED_CABIN_LANDING_ONLY")
    if not _text(ledger.get("boundary_note")):
        errors.append("boundary_note is required")

    states = ledger.get("states")
    if not isinstance(states, list) or not states or any(not isinstance(row, dict) for row in states):
        errors.append("states must be a non-empty array of objects")
        states = []
    seen_states: set[str] = set()
    for index, state in enumerate(states):
        prefix = f"states[{index}]"
        name = state.get("name")
        if name not in STATES:
            errors.append(f"{prefix}.name is invalid")
        elif name in seen_states:
            errors.append(f"{prefix}.name is duplicated")
        else:
            seen_states.add(name)
        if state.get("bus") != "Ambience":
            errors.append(f"{prefix}.bus must be Ambience")
        if state.get("authority") != "presentation_only":
            errors.append(f"{prefix}.authority must be presentation_only")
        if not _text(state.get("evidence")):
            errors.append(f"{prefix}.evidence is required")
    if STATES - seen_states:
        errors.append(f"states must cover: {', '.join(sorted(STATES - seen_states))}")

    transitions = ledger.get("transitions")
    if not isinstance(transitions, list) or not transitions:
        errors.append("transitions must be a non-empty array")
        transitions = []
    seen_paths: set[tuple[Any, Any]] = set()
    for index, transition in enumerate(transitions):
        prefix = f"transitions[{index}]"
        if not isinstance(transition, dict):
            errors.append(f"{prefix} must be an object")
            continue
        pair = (transition.get("from"), transition.get("to"))
        if pair in seen_paths:
            errors.append(f"{prefix}.from/to is duplicated")
        seen_paths.add(pair)
        if pair not in PATHS:
            errors.append(f"{prefix}.from/to is invalid")
        actions = transition.get("actions")
        if not isinstance(actions, list) or not actions or any(action not in ACTIONS for action in actions) or len(actions) != len(set(actions)):
            errors.append(f"{prefix}.actions must be unique supported actions")
        if not _text(transition.get("evidence")):
            errors.append(f"{prefix}.evidence is required")
        if transition.get("authority") != "presentation_only":
            errors.append(f"{prefix}.authority must be presentation_only")
    if PATHS - seen_paths:
        errors.append("transitions missing required cabin/landing paths")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("ledger", type=Path)
    args = parser.parse_args(argv)
    errors = validate_ledger(json.loads(args.ledger.read_text(encoding="utf-8")))
    if errors:
        print("AUDIO_AMBIENCE_CABIN_LANDING_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("AUDIO_AMBIENCE_CABIN_LANDING_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
