#!/usr/bin/env python3
"""Validate detached planetary activity objective state transitions.

The evidence fixture checks legal success/failure/recovery transitions, one
completion and one reward handoff per activity generation, and stale-generation
rejection.  It never advances an ActivityDirector or mutates gameplay state.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 1
EVIDENCE_SCOPE = "planetary_activity_objective_state"
EVIDENCE_MODE = "detached_transition_fixture"
REQUIRED_WORLD_ID = "ember_moon"
REQUIRED_ACTIVITY_IDS = (
    "ember_beacon_survey",
    "ember_caldera_patrol",
    "ember_kit_cargo_run",
    "ember_checkpoint_race",
    "ember_convoy_escort",
)
REQUIRED_SUCCESS_PATH = ("idle", "active", "completed", "reward_queued", "return_presented", "returned")
REQUIRED_FAILURE_PATH = ("active", "failed", "recovered", "reset")


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _positive_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value > 0


def validate_transitions(value: Any, label: str = "evidence") -> list[str]:
    """Return blocking errors for one detached objective transition fixture."""

    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    if value.get("evidence_scope") != EVIDENCE_SCOPE:
        errors.append(f"{label}.evidence_scope must be {EVIDENCE_SCOPE}")
    if value.get("evidence_mode") != EVIDENCE_MODE:
        errors.append(f"{label}.evidence_mode must be {EVIDENCE_MODE}")
    for key in ("runtime_authority", "objective_mutated", "reward_granted", "native_claims"):
        if value.get(key) is not False:
            errors.append(f"{label}.{key} must be false")
    if value.get("world_id") != REQUIRED_WORLD_ID:
        errors.append(f"{label}.world_id must be {REQUIRED_WORLD_ID}")
    if not _text(value.get("source_revision")):
        errors.append(f"{label}.source_revision is required")

    activities = value.get("activities")
    if not isinstance(activities, list) or len(activities) != len(REQUIRED_ACTIVITY_IDS):
        errors.append(f"{label}.activities must contain exactly five authored activities")
        activities = []
    activity_ids: list[str] = []
    for index, activity in enumerate(activities):
        prefix = f"{label}.activities[{index}]"
        if not isinstance(activity, dict):
            errors.append(f"{prefix} must be an object")
            continue
        activity_id = activity.get("activity_id")
        activity_ids.append(activity_id)
        if activity_id != REQUIRED_ACTIVITY_IDS[index]:
            errors.append(f"{prefix}.activity_id must be {REQUIRED_ACTIVITY_IDS[index]}")
        if not _text(activity.get("objective_id")):
            errors.append(f"{prefix}.objective_id is required")
        generation = activity.get("generation")
        if not _positive_int(generation):
            errors.append(f"{prefix}.generation must be positive")
        success = activity.get("success_path")
        if tuple(success or []) != REQUIRED_SUCCESS_PATH:
            errors.append(f"{prefix}.success_path must contain the exact success transition path")
        failure = activity.get("failure_path")
        if tuple(failure or []) != REQUIRED_FAILURE_PATH:
            errors.append(f"{prefix}.failure_path must contain the exact failure/recovery path")
        for key in ("completed_once", "reward_queued_once", "return_presented_once", "failure_recovered", "stale_generation_rejected", "duplicate_completion_rejected", "duplicate_reward_rejected"):
            if activity.get(key) is not True:
                errors.append(f"{prefix}.{key} must be true")
        transitions = activity.get("observations")
        if not isinstance(transitions, list) or not transitions:
            errors.append(f"{prefix}.observations must be a non-empty array")
            continue
        sequences: list[int] = []
        observed_states: list[str] = []
        for transition_index, transition in enumerate(transitions):
            transition_prefix = f"{prefix}.observations[{transition_index}]"
            if not isinstance(transition, dict):
                errors.append(f"{transition_prefix} must be an object")
                continue
            if not _text(transition.get("from")) or not _text(transition.get("to")):
                errors.append(f"{transition_prefix} requires from and to states")
            else:
                observed_states.append(transition["to"])
            sequence = transition.get("sequence")
            if not isinstance(sequence, int) or isinstance(sequence, bool) or sequence < 0:
                errors.append(f"{transition_prefix}.sequence must be non-negative")
            else:
                sequences.append(sequence)
            if transition.get("accepted") is not True:
                errors.append(f"{transition_prefix}.accepted must be true")
            if transition.get("committed_once") is not True:
                errors.append(f"{transition_prefix}.committed_once must be true")
            if transition.get("generation") != generation:
                errors.append(f"{transition_prefix}.generation must match activity generation")
        if sequences != list(range(len(sequences))):
            errors.append(f"{prefix}.observations sequences must be contiguous from zero")
        if "completed" not in observed_states or "reward_queued" not in observed_states:
            errors.append(f"{prefix}.observations must witness completion and reward queueing")
    if tuple(activity_ids) != REQUIRED_ACTIVITY_IDS:
        errors.append(f"{label}.activities must retain the authored activity order")

    stale = value.get("stale_attempt")
    if not isinstance(stale, dict):
        errors.append(f"{label}.stale_attempt must be an object")
    else:
        if stale.get("accepted") is not False:
            errors.append(f"{label}.stale_attempt.accepted must be false")
        if stale.get("reason") not in {"stale_generation", "activity_generation_mismatch"}:
            errors.append(f"{label}.stale_attempt.reason must name a generation rejection")
        if not _positive_int(stale.get("submitted_generation")) or not _positive_int(stale.get("current_generation")):
            errors.append(f"{label}.stale_attempt generations must be positive")
        elif stale["submitted_generation"] >= stale["current_generation"]:
            errors.append(f"{label}.stale_attempt.current_generation must be newer")

    authority = value.get("authority")
    if not isinstance(authority, dict):
        errors.append(f"{label}.authority must be an object")
    else:
        for key in ("activity", "objective", "reward", "recovery", "save", "network", "gameplay", "clock"):
            if authority.get(key) is not False:
                errors.append(f"{label}.authority.{key} must be false")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("evidence", type=Path)
    args = parser.parse_args(argv)
    try:
        report = json.loads(args.evidence.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        print(f"PLANETARY_ACTIVITY_STATE_INVALID: {exc}")
        return 1
    errors = validate_transitions(report)
    if errors:
        print("PLANETARY_ACTIVITY_STATE_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PLANETARY_ACTIVITY_STATE_VALID: detached transition evidence only")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
