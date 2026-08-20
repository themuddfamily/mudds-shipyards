#!/usr/bin/env python3
"""Validate ambience state-transition action evidence without native audition."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


SCHEMA = "audio_ambience_state_transition_evidence_v1"
STATES = {"exterior", "interior", "cabin", "landing"}
REQUIRED_PATHS = {("exterior", "interior"), ("interior", "exterior"), ("exterior", "landing"), ("landing", "exterior")}
ACTIONS = {"start", "stop", "retain", "fade_in", "fade_out"}


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
    if ledger.get("claim") != "AUTOMATED_TRANSITION_ONLY":
        errors.append("claim must be AUTOMATED_TRANSITION_ONLY")
    if not _text(ledger.get("boundary_note")):
        errors.append("boundary_note is required")

    states = ledger.get("states")
    if not isinstance(states, list) or not states or any(not isinstance(row, dict) for row in states):
        errors.append("states must be a non-empty array of objects")
        states = []
    state_ids: set[str] = set()
    for index, state in enumerate(states):
        prefix = f"states[{index}]"
        name = state.get("name")
        if name not in STATES:
            errors.append(f"{prefix}.name is invalid")
        elif name in state_ids:
            errors.append(f"{prefix}.name is duplicated")
        else:
            state_ids.add(name)
        for key in ("entry_evidence", "exit_evidence"):
            if not _text(state.get(key)):
                errors.append(f"{prefix}.{key} is required")
        if state.get("voice_owner") != "presentation_only":
            errors.append(f"{prefix}.voice_owner must be presentation_only")
    missing_states = STATES - state_ids
    if missing_states:
        errors.append(f"states must cover: {', '.join(sorted(missing_states))}")

    transitions = ledger.get("transitions")
    if not isinstance(transitions, list) or not transitions:
        errors.append("transitions must be a non-empty array")
        transitions = []
    seen: set[tuple[Any, Any]] = set()
    for index, transition in enumerate(transitions):
        prefix = f"transitions[{index}]"
        if not isinstance(transition, dict):
            errors.append(f"{prefix} must be an object")
            continue
        pair = (transition.get("from"), transition.get("to"))
        if pair in seen:
            errors.append(f"{prefix}.from/to is duplicated")
        seen.add(pair)
        if pair not in REQUIRED_PATHS:
            errors.append(f"{prefix}.from/to is invalid")
        actions = transition.get("actions")
        if not isinstance(actions, list) or not actions or any(action not in ACTIONS for action in actions) or len(actions) != len(set(actions)):
            errors.append(f"{prefix}.actions must be a unique list of supported actions")
        if not _text(transition.get("evidence")):
            errors.append(f"{prefix}.evidence is required")
        if transition.get("authority") != "presentation_only":
            errors.append(f"{prefix}.authority must be presentation_only")
    if REQUIRED_PATHS - seen:
        errors.append("transitions missing required ambience paths")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("ledger", type=Path)
    args = parser.parse_args(argv)
    errors = validate_ledger(json.loads(args.ledger.read_text(encoding="utf-8")))
    if errors:
        print("AUDIO_AMBIENCE_STATE_TRANSITION_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("AUDIO_AMBIENCE_STATE_TRANSITION_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
