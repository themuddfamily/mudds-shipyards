#!/usr/bin/env python3
"""Validate detached planetary objective event ID uniqueness and ordering.

The catalog is an authored index of deterministic event IDs for each Ember
activity.  It checks identity, order, and sequence only; it does not emit
events, resolve objectives, or grant rewards at runtime.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 1
EVIDENCE_SCOPE = "planetary_objective_event_id_order"
EVIDENCE_MODE = "detached_event_catalog"
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


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _stable(value: Any) -> bool:
    return _text(value) and value == value.lower() and " " not in value and "__" not in value


def _unique(values: list[Any], label: str, errors: list[str]) -> None:
    if len(set(values)) != len(values):
        errors.append(f"{label} must not contain duplicates")


def validate_catalog(value: Any, label: str = "catalog") -> list[str]:
    """Return blocking errors for one detached objective event catalog."""

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
    if value.get("event_count") != len(REQUIRED_ACTIVITY_IDS) * len(EXPECTED_EVENT_TYPES):
        errors.append(f"{label}.event_count must be exactly thirty")
    if not _text(value.get("source_revision")):
        errors.append(f"{label}.source_revision is required")

    activities = value.get("activities")
    if not isinstance(activities, list) or len(activities) != len(REQUIRED_ACTIVITY_IDS):
        errors.append(f"{label}.activities must contain exactly five authored activities")
        activities = []
    activity_ids: list[Any] = []
    objective_ids: list[Any] = []
    all_event_ids: list[Any] = []
    observed_count = 0
    for activity_index, activity in enumerate(activities):
        prefix = f"{label}.activities[{activity_index}]"
        if not isinstance(activity, dict):
            errors.append(f"{prefix} must be an object")
            continue
        activity_id = activity.get("activity_id")
        activity_ids.append(activity_id)
        if activity_id != REQUIRED_ACTIVITY_IDS[activity_index]:
            errors.append(f"{prefix}.activity_id must be {REQUIRED_ACTIVITY_IDS[activity_index]}")
        objective_id = activity.get("objective_id")
        objective_ids.append(objective_id)
        if not _stable(objective_id):
            errors.append(f"{prefix}.objective_id must be stable lowercase text")
        if activity.get("activity_authority_id") not in EXISTING_ACTIVITY_AUTHORITIES:
            errors.append(f"{prefix}.activity_authority_id must use an existing activity authority")
        if activity.get("reward_store_id") != REQUIRED_REWARD_STORE:
            errors.append(f"{prefix}.reward_store_id must use the one canonical reward store")
        events = activity.get("events")
        if not isinstance(events, list) or len(events) != len(EXPECTED_EVENT_TYPES):
            errors.append(f"{prefix}.events must contain exactly six ordered events")
            events = []
        observed_types: list[Any] = []
        observed_sequences: list[Any] = []
        activity_event_ids: list[Any] = []
        for event_index, event in enumerate(events):
            event_prefix = f"{prefix}.events[{event_index}]"
            if not isinstance(event, dict):
                errors.append(f"{event_prefix} must be an object")
                continue
            observed_count += 1
            event_type = event.get("type")
            event_id = event.get("event_id")
            expected_type = EXPECTED_EVENT_TYPES[event_index]
            expected_id = f"{activity_id}_{expected_type}" if _text(activity_id) else expected_type
            observed_types.append(event_type)
            observed_sequences.append(event.get("sequence"))
            activity_event_ids.append(event_id)
            all_event_ids.append(event_id)
            if event_type != expected_type:
                errors.append(f"{event_prefix}.type must be {expected_type}")
            if event_id != expected_id:
                errors.append(f"{event_prefix}.event_id must be {expected_id}")
            if not _stable(event_id):
                errors.append(f"{event_prefix}.event_id must be stable lowercase text")
            if event.get("sequence") != event_index:
                errors.append(f"{event_prefix}.sequence must be contiguous from zero")
            if event.get("occurrence") != 1:
                errors.append(f"{event_prefix}.occurrence must be exactly one")
        _unique(activity_event_ids, f"{prefix}.event_ids", errors)
        if tuple(observed_types) != EXPECTED_EVENT_TYPES:
            errors.append(f"{prefix}.events must retain authored objective event order")
        if observed_sequences != list(range(len(EXPECTED_EVENT_TYPES))):
            errors.append(f"{prefix}.events sequences must be contiguous from zero")
    if tuple(activity_ids) != REQUIRED_ACTIVITY_IDS:
        errors.append(f"{label}.activities must retain authored activity order")
    _unique(objective_ids, f"{label}.objective_ids", errors)
    _unique(all_event_ids, f"{label}.event_ids", errors)
    if observed_count != value.get("event_count"):
        errors.append(f"{label}.event_count must match the authored event records")

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
    parser.add_argument("catalog", type=Path)
    args = parser.parse_args(argv)
    try:
        report = json.loads(args.catalog.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        print(f"PLANETARY_EVENT_CATALOG_INVALID: {exc}")
        return 1
    errors = validate_catalog(report)
    if errors:
        print("PLANETARY_EVENT_CATALOG_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PLANETARY_EVENT_CATALOG_VALID: detached event IDs/order only")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
