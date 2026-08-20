#!/usr/bin/env python3
"""Validate detached planetary objective event sequence continuity.

The stream is an authored, flat ordering of objective/outcome events.  It
proves global and per-activity sequence continuity and unique IDs without
emitting events or owning objective/reward runtime state.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 1
EVIDENCE_SCOPE = "planetary_objective_event_sequence_contiguous"
EVIDENCE_MODE = "detached_contiguous_event_stream"
REQUIRED_WORLD_ID = "ember_moon"
REQUIRED_REWARD_STORE = "game_flow_reward_store"
REQUIRED_ACTIVITY_IDS = (
    "ember_beacon_survey",
    "ember_caldera_patrol",
    "ember_kit_cargo_run",
    "ember_checkpoint_race",
    "ember_convoy_escort",
)
EXISTING_ACTIVITY_AUTHORITIES = {
    "activity_director",
    "cargo_delivery_activity",
    "timed_checkpoint_race",
    "convoy_escort_activity",
}
EXPECTED_EVENT_TYPES = (
    "objective_started",
    "objective_completed",
    "reward_queued",
    "reward_granted",
    "return_presented",
    "returned",
)
EVENTS_PER_ACTIVITY = len(EXPECTED_EVENT_TYPES)
TOTAL_EVENTS = len(REQUIRED_ACTIVITY_IDS) * EVENTS_PER_ACTIVITY


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _stable(value: Any) -> bool:
    return _text(value) and value == value.lower() and " " not in value and "__" not in value


def _unique(values: list[Any], label: str, errors: list[str]) -> None:
    if len(set(values)) != len(values):
        errors.append(f"{label} must not contain duplicates")


def validate_stream(value: Any, label: str = "stream") -> list[str]:
    """Return blocking errors for one detached contiguous event stream."""

    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    if value.get("evidence_scope") != EVIDENCE_SCOPE:
        errors.append(f"{label}.evidence_scope must be {EVIDENCE_SCOPE}")
    if value.get("evidence_mode") != EVIDENCE_MODE:
        errors.append(f"{label}.evidence_mode must be {EVIDENCE_MODE}")
    for key in ("runtime_authority", "objective_runtime", "reward_inventory", "native_claims"):
        if value.get(key) is not False:
            errors.append(f"{label}.{key} must be false")
    if value.get("world_id") != REQUIRED_WORLD_ID:
        errors.append(f"{label}.world_id must be {REQUIRED_WORLD_ID}")
    if value.get("reward_store_id") != REQUIRED_REWARD_STORE:
        errors.append(f"{label}.reward_store_id must use the one canonical reward store")
    if value.get("event_count") != TOTAL_EVENTS:
        errors.append(f"{label}.event_count must be {TOTAL_EVENTS}")
    if not _text(value.get("source_revision")):
        errors.append(f"{label}.source_revision is required")

    activities = value.get("activities")
    if not isinstance(activities, list) or len(activities) != len(REQUIRED_ACTIVITY_IDS):
        errors.append(f"{label}.activities must contain exactly five authored activities")
        activities = []
    activity_ids: list[Any] = []
    authority_by_activity: dict[str, Any] = {}
    for index, activity in enumerate(activities):
        prefix = f"{label}.activities[{index}]"
        if not isinstance(activity, dict):
            errors.append(f"{prefix} must be an object")
            continue
        activity_id = activity.get("activity_id")
        activity_ids.append(activity_id)
        if activity_id != REQUIRED_ACTIVITY_IDS[index]:
            errors.append(f"{prefix}.activity_id must be {REQUIRED_ACTIVITY_IDS[index]}")
        authority_by_activity[activity_id] = activity.get("activity_authority_id")
        if activity.get("activity_authority_id") not in EXISTING_ACTIVITY_AUTHORITIES:
            errors.append(f"{prefix}.activity_authority_id must use an existing activity authority")
        if not _stable(activity.get("objective_id")):
            errors.append(f"{prefix}.objective_id must be stable lowercase text")
    if tuple(activity_ids) != REQUIRED_ACTIVITY_IDS:
        errors.append(f"{label}.activities must retain authored activity order")

    events = value.get("events")
    if not isinstance(events, list) or len(events) != TOTAL_EVENTS:
        errors.append(f"{label}.events must contain exactly thirty ordered events")
        events = []
    event_ids: list[Any] = []
    observed_global_sequences: list[Any] = []
    for event_index, event in enumerate(events):
        prefix = f"{label}.events[{event_index}]"
        if not isinstance(event, dict):
            errors.append(f"{prefix} must be an object")
            continue
        activity_index = event_index // EVENTS_PER_ACTIVITY
        local_index = event_index % EVENTS_PER_ACTIVITY
        expected_activity = REQUIRED_ACTIVITY_IDS[activity_index]
        expected_type = EXPECTED_EVENT_TYPES[local_index]
        event_id = event.get("event_id")
        event_ids.append(event_id)
        observed_global_sequences.append(event.get("global_sequence"))
        if event.get("activity_id") != expected_activity:
            errors.append(f"{prefix}.activity_id must be {expected_activity}")
        if event.get("activity_authority_id") != authority_by_activity.get(expected_activity):
            errors.append(f"{prefix}.activity_authority_id must match its authored activity")
        if event.get("type") != expected_type:
            errors.append(f"{prefix}.type must be {expected_type}")
        if event_id != f"{expected_activity}_{expected_type}":
            errors.append(f"{prefix}.event_id must be deterministic for its activity and type")
        if not _stable(event_id):
            errors.append(f"{prefix}.event_id must be stable lowercase text")
        if event.get("global_sequence") != event_index:
            errors.append(f"{prefix}.global_sequence must be contiguous from zero")
        if event.get("activity_sequence") != local_index:
            errors.append(f"{prefix}.activity_sequence must be contiguous from zero")
        if event.get("occurrence") != 1:
            errors.append(f"{prefix}.occurrence must be exactly one")
    _unique(event_ids, f"{label}.event_ids", errors)
    if observed_global_sequences != list(range(TOTAL_EVENTS)):
        errors.append(f"{label}.global_sequences must be contiguous from zero")

    authority = value.get("authority")
    if not isinstance(authority, dict):
        errors.append(f"{label}.authority must be an object")
    else:
        for key in ("activity", "objective", "reward", "reward_store", "save", "network", "gameplay"):
            if authority.get(key) is not False:
                errors.append(f"{label}.authority.{key} must be false")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("stream", type=Path)
    args = parser.parse_args(argv)
    try:
        report = json.loads(args.stream.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        print(f"PLANETARY_EVENT_STREAM_INVALID: {exc}")
        return 1
    errors = validate_stream(report)
    if errors:
        print("PLANETARY_EVENT_STREAM_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PLANETARY_EVENT_STREAM_VALID: detached contiguous sequence only")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
