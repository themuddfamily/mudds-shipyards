#!/usr/bin/env python3
"""Validate a detached planetary objective/reward/return event ledger.

The ledger records the authored exactly-once event sequence for each Ember
activity.  It references existing activity, GameFlow reward, reward-store,
and landing-return authorities; it does not execute an objective, grant an
inventory item, or move a player.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 1
EVIDENCE_SCOPE = "planetary_objective_exactly_once_reward_return"
EVIDENCE_MODE = "detached_event_ledger"
REQUIRED_WORLD_ID = "ember_moon"
REQUIRED_RETURN_TARGET = "mudds_shipyards"
REQUIRED_REWARD_AUTHORITY = "game_flow_reward_authority"
REQUIRED_REWARD_STORE = "game_flow_reward_store"
REQUIRED_RETURN_AUTHORITY = "planetary_landing_return_contract"
EXISTING_ACTIVITY_AUTHORITIES = {
    "activity_director",
    "cargo_delivery_activity",
    "timed_checkpoint_race",
    "convoy_escort_activity",
}
REQUIRED_ACTIVITY_IDS = (
    "ember_beacon_survey",
    "ember_caldera_patrol",
    "ember_kit_cargo_run",
    "ember_checkpoint_race",
    "ember_convoy_escort",
)
EXPECTED_EVENT_TYPES = (
    "objective_accepted",
    "objective_completed",
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


def validate_ledger(value: Any, label: str = "ledger") -> list[str]:
    """Return blocking errors for one detached exactly-once event ledger."""

    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    if value.get("evidence_scope") != EVIDENCE_SCOPE:
        errors.append(f"{label}.evidence_scope must be {EVIDENCE_SCOPE}")
    if value.get("evidence_mode") != EVIDENCE_MODE:
        errors.append(f"{label}.evidence_mode must be {EVIDENCE_MODE}")
    for key in ("runtime_authority", "objective_runtime", "reward_inventory", "return_runtime", "native_claims"):
        if value.get(key) is not False:
            errors.append(f"{label}.{key} must be false")
    if value.get("world_id") != REQUIRED_WORLD_ID:
        errors.append(f"{label}.world_id must be {REQUIRED_WORLD_ID}")
    if value.get("return_target_id") != REQUIRED_RETURN_TARGET:
        errors.append(f"{label}.return_target_id must be {REQUIRED_RETURN_TARGET}")
    if value.get("reward_store_id") != REQUIRED_REWARD_STORE:
        errors.append(f"{label}.reward_store_id must use the one canonical reward store")
    store_ids = value.get("reward_store_ids")
    if store_ids != [REQUIRED_REWARD_STORE]:
        errors.append(f"{label}.reward_store_ids must contain one canonical store only")
    if not _text(value.get("source_revision")):
        errors.append(f"{label}.source_revision is required")

    activities = value.get("activities")
    if not isinstance(activities, list) or len(activities) != len(REQUIRED_ACTIVITY_IDS):
        errors.append(f"{label}.activities must contain exactly five authored activities")
        activities = []
    activity_ids: list[Any] = []
    objective_ids: list[Any] = []
    reward_ids: list[Any] = []
    incentive_ids: list[Any] = []
    event_ids: list[Any] = []
    for index, activity in enumerate(activities):
        prefix = f"{label}.activities[{index}]"
        if not isinstance(activity, dict):
            errors.append(f"{prefix} must be an object")
            continue
        activity_id = activity.get("activity_id")
        activity_ids.append(activity_id)
        if activity_id != REQUIRED_ACTIVITY_IDS[index]:
            errors.append(f"{prefix}.activity_id must be {REQUIRED_ACTIVITY_IDS[index]}")
        objective_id = activity.get("objective_id")
        reward_id = activity.get("reward_id")
        incentive_id = activity.get("return_incentive_id")
        objective_ids.append(objective_id)
        reward_ids.append(reward_id)
        incentive_ids.append(incentive_id)
        for key, item in (("activity_id", activity_id), ("objective_id", objective_id), ("reward_id", reward_id), ("return_incentive_id", incentive_id)):
            if not _stable(item):
                errors.append(f"{prefix}.{key} must be stable lowercase text")
        if activity.get("activity_authority_id") not in EXISTING_ACTIVITY_AUTHORITIES:
            errors.append(f"{prefix}.activity_authority_id must name an existing activity authority")
        if activity.get("reward_authority_id") != REQUIRED_REWARD_AUTHORITY:
            errors.append(f"{prefix}.reward_authority_id must be {REQUIRED_REWARD_AUTHORITY}")
        if activity.get("reward_store_id") != REQUIRED_REWARD_STORE:
            errors.append(f"{prefix}.reward_store_id must use the one canonical reward store")
        if activity.get("return_authority_id") != REQUIRED_RETURN_AUTHORITY:
            errors.append(f"{prefix}.return_authority_id must be {REQUIRED_RETURN_AUTHORITY}")
        if activity.get("return_target_id") != REQUIRED_RETURN_TARGET:
            errors.append(f"{prefix}.return_target_id must be {REQUIRED_RETURN_TARGET}")
        for key in ("objective_completed_once", "reward_granted_once", "return_presented_once", "returned_once", "duplicate_objective_rejected", "duplicate_reward_rejected", "duplicate_return_rejected"):
            if activity.get(key) is not True:
                errors.append(f"{prefix}.{key} must be true")

        events = activity.get("events")
        if not isinstance(events, list) or len(events) != len(EXPECTED_EVENT_TYPES):
            errors.append(f"{prefix}.events must contain exactly five ordered events")
            events = []
        event_types: list[Any] = []
        activity_event_ids: list[Any] = []
        for event_index, event in enumerate(events):
            event_prefix = f"{prefix}.events[{event_index}]"
            if not isinstance(event, dict):
                errors.append(f"{event_prefix} must be an object")
                continue
            event_type = event.get("type")
            event_id = event.get("event_id")
            event_types.append(event_type)
            activity_event_ids.append(event_id)
            event_ids.append(event_id)
            if event_type != EXPECTED_EVENT_TYPES[event_index]:
                errors.append(f"{event_prefix}.type must be {EXPECTED_EVENT_TYPES[event_index]}")
            if not _stable(event_id):
                errors.append(f"{event_prefix}.event_id must be stable lowercase text")
            if event.get("occurrence") != 1:
                errors.append(f"{event_prefix}.occurrence must be exactly one")
        _unique(activity_event_ids, f"{prefix}.event_ids", errors)
        if tuple(event_types) != EXPECTED_EVENT_TYPES:
            errors.append(f"{prefix}.events must retain the authored objective/reward/return order")
        if len(events) == len(EXPECTED_EVENT_TYPES):
            if activity.get("reward_event_id") != events[2].get("event_id"):
                errors.append(f"{prefix}.reward_event_id must reference the reward_granted event")
            if activity.get("return_event_id") != events[4].get("event_id"):
                errors.append(f"{prefix}.return_event_id must reference the returned event")
    if tuple(activity_ids) != REQUIRED_ACTIVITY_IDS:
        errors.append(f"{label}.activities must retain authored activity order")
    _unique(objective_ids, f"{label}.objective_ids", errors)
    _unique(reward_ids, f"{label}.reward_ids", errors)
    _unique(incentive_ids, f"{label}.return_incentive_ids", errors)
    _unique(event_ids, f"{label}.event_ids", errors)

    authority = value.get("authority")
    if not isinstance(authority, dict):
        errors.append(f"{label}.authority must be an object")
    else:
        for key in ("objective", "activity", "reward", "reward_store", "return", "save", "network", "gameplay"):
            if authority.get(key) is not False:
                errors.append(f"{label}.authority.{key} must be false")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("ledger", type=Path)
    args = parser.parse_args(argv)
    try:
        report = json.loads(args.ledger.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        print(f"PLANETARY_OBJECTIVE_EVENT_LEDGER_INVALID: {exc}")
        return 1
    errors = validate_ledger(report)
    if errors:
        print("PLANETARY_OBJECTIVE_EVENT_LEDGER_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PLANETARY_OBJECTIVE_EVENT_LEDGER_VALID: detached exactly-once evidence only")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
