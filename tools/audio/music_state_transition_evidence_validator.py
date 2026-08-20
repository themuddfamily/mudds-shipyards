#!/usr/bin/env python3
"""Validate music state-transition evidence while keeping audition open."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


SCHEMA = "music_state_transition_evidence_v1"
REQUIRED_STATES = {"station_rest", "encounter", "return"}
REQUIRED_TRANSITIONS = {("station_rest", "encounter"), ("encounter", "return"), ("return", "station_rest")}


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _bool(value: Any) -> bool:
    return isinstance(value, bool)


def validate_record(record: Any) -> list[str]:
    if not isinstance(record, dict):
        return ["record must be an object"]
    errors: list[str] = []
    if record.get("schema") != SCHEMA:
        errors.append(f"schema must be {SCHEMA}")
    for key in ("revision", "music_owner", "evidence_bundle"):
        if not _text(record.get(key)):
            errors.append(f"{key} is required")
    if record.get("audition_status") not in {"OPEN", "PASS", "FAILED"}:
        errors.append("audition_status is invalid")
    if record.get("audition_status") == "OPEN" and not _text(record.get("audition_boundary")):
        errors.append("audition_boundary is required while audition_status is OPEN")

    states = record.get("states")
    if not isinstance(states, list) or not states or any(not isinstance(item, dict) for item in states):
        errors.append("states must be a non-empty array of objects")
        states = []
    state_ids: set[str] = set()
    for index, state in enumerate(states):
        prefix = f"states[{index}]"
        state_id = state.get("id")
        if state_id not in REQUIRED_STATES:
            errors.append(f"{prefix}.id is invalid")
        elif state_id in state_ids:
            errors.append(f"{prefix}.id is duplicated")
        else:
            state_ids.add(state_id)
        for key in ("entry_evidence", "exit_evidence", "bus"):
            if not _text(state.get(key)):
                errors.append(f"{prefix}.{key} is required")
        if not _bool(state.get("silences_on_encounter")):
            errors.append(f"{prefix}.silences_on_encounter must be boolean")
        if not _bool(state.get("retains_position_on_reentry")):
            errors.append(f"{prefix}.retains_position_on_reentry must be boolean")
    missing_states = REQUIRED_STATES - state_ids
    if missing_states:
        errors.append(f"states must cover: {', '.join(sorted(missing_states))}")

    transitions = record.get("transitions")
    seen: set[tuple[Any, Any]] = set()
    if not isinstance(transitions, list) or not transitions:
        errors.append("transitions must be a non-empty array")
        transitions = []
    for index, transition in enumerate(transitions):
        prefix = f"transitions[{index}]"
        if not isinstance(transition, dict):
            errors.append(f"{prefix} must be an object")
            continue
        pair = (transition.get("from"), transition.get("to"))
        if pair in seen:
            errors.append(f"{prefix}.from/to is duplicated")
        seen.add(pair)
        if pair not in REQUIRED_TRANSITIONS:
            errors.append(f"{prefix}.from/to is invalid")
        for key in ("trigger_evidence", "result_evidence"):
            if not _text(transition.get(key)):
                errors.append(f"{prefix}.{key} is required")
        if transition.get("presentation_only") is not True:
            errors.append(f"{prefix}.presentation_only must be true")
    missing_transitions = REQUIRED_TRANSITIONS - seen
    if missing_transitions:
        errors.append("transitions missing required state paths")

    exclusions = record.get("authority_exclusions")
    if not isinstance(exclusions, list) or not exclusions or any(not _text(item) for item in exclusions):
        errors.append("authority_exclusions must be a non-empty list of strings")
    else:
        for required in ("gameplay_phase", "damage", "reward"):
            if required not in exclusions:
                errors.append(f"authority_exclusions missing {required}")
    if record.get("audition_status") == "PASS" and not _text(record.get("audition_evidence")):
        errors.append("audition_evidence is required for PASS")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("record", type=Path)
    args = parser.parse_args(argv)
    errors = validate_record(json.loads(args.record.read_text(encoding="utf-8")))
    if errors:
        print("MUSIC_STATE_TRANSITION_EVIDENCE_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("MUSIC_STATE_TRANSITION_EVIDENCE_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
