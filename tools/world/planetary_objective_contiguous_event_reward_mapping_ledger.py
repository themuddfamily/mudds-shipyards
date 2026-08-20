#!/usr/bin/env python3
"""Validate detached planetary contiguous event/reward mappings.

The ledger joins each authored objective event sequence to its reward queue /
grant and return incentive records.  It owns no reward inventory, objective
state, movement, or runtime authority.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 1
EVIDENCE_SCOPE = "planetary_objective_contiguous_event_reward_mapping"
EVIDENCE_MODE = "detached_event_reward_mapping"
REQUIRED_WORLD_ID = "ember_moon"
REQUIRED_RETURN_TARGET = "mudds_shipyards"
REQUIRED_REWARD_AUTHORITY = "game_flow_reward_authority"
REQUIRED_REWARD_STORE = "game_flow_reward_store"
REQUIRED_RETURN_AUTHORITY = "planetary_landing_return_contract"
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
REWARD_EVENT_TYPES = {"reward_queued", "reward_granted"}
RETURN_EVENT_TYPES = {"return_presented", "returned"}


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _stable(value: Any) -> bool:
    return _text(value) and value == value.lower() and " " not in value and "__" not in value


def _unique(values: list[Any], label: str, errors: list[str]) -> None:
    if len(set(values)) != len(values):
        errors.append(f"{label} must not contain duplicates")


def validate_mapping(value: Any, label: str = "ledger") -> list[str]:
    """Return blocking errors for one detached event/reward mapping ledger."""

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
    if value.get("reward_store_ids") != [REQUIRED_REWARD_STORE]:
        errors.append(f"{label}.reward_store_ids must contain one canonical store only")
    if not _text(value.get("source_revision")):
        errors.append(f"{label}.source_revision is required")

    activities = value.get("activities")
    if not isinstance(activities, list) or len(activities) != len(REQUIRED_ACTIVITY_IDS):
        errors.append(f"{label}.activities must contain exactly five authored activities")
        activities = []
    activity_ids: list[Any] = []
    reward_ids: list[Any] = []
    incentive_ids: list[Any] = []
    event_ids: list[Any] = []
    for activity_index, activity in enumerate(activities):
        prefix = f"{label}.activities[{activity_index}]"
        if not isinstance(activity, dict):
            errors.append(f"{prefix} must be an object")
            continue
        activity_id = activity.get("activity_id")
        activity_ids.append(activity_id)
        if activity_id != REQUIRED_ACTIVITY_IDS[activity_index]:
            errors.append(f"{prefix}.activity_id must be {REQUIRED_ACTIVITY_IDS[activity_index]}")
        if not _stable(activity.get("objective_id")):
            errors.append(f"{prefix}.objective_id must be stable lowercase text")
        if activity.get("activity_authority_id") not in EXISTING_ACTIVITY_AUTHORITIES:
            errors.append(f"{prefix}.activity_authority_id must use an existing activity authority")
        if activity.get("reward_authority_id") != REQUIRED_REWARD_AUTHORITY:
            errors.append(f"{prefix}.reward_authority_id must be {REQUIRED_REWARD_AUTHORITY}")
        if activity.get("return_authority_id") != REQUIRED_RETURN_AUTHORITY:
            errors.append(f"{prefix}.return_authority_id must be {REQUIRED_RETURN_AUTHORITY}")
        if activity.get("return_target_id") != REQUIRED_RETURN_TARGET:
            errors.append(f"{prefix}.return_target_id must be {REQUIRED_RETURN_TARGET}")
        reward_id = activity.get("reward_id")
        incentive_id = activity.get("return_incentive_id")
        reward_ids.append(reward_id)
        incentive_ids.append(incentive_id)
        if not _stable(reward_id):
            errors.append(f"{prefix}.reward_id must be stable lowercase text")
        if not _stable(incentive_id) or not incentive_id.startswith("return_"):
            errors.append(f"{prefix}.return_incentive_id must begin with return_")

        mappings = activity.get("mappings")
        if not isinstance(mappings, list) or len(mappings) != len(EXPECTED_EVENT_TYPES):
            errors.append(f"{prefix}.mappings must contain exactly six ordered event mappings")
            mappings = []
        observed_types: list[Any] = []
        observed_sequences: list[Any] = []
        activity_event_ids: list[Any] = []
        for mapping_index, mapping in enumerate(mappings):
            mapping_prefix = f"{prefix}.mappings[{mapping_index}]"
            if not isinstance(mapping, dict):
                errors.append(f"{mapping_prefix} must be an object")
                continue
            expected_type = EXPECTED_EVENT_TYPES[mapping_index]
            expected_event_id = f"{activity_id}_{expected_type}" if _text(activity_id) else expected_type
            event_type = mapping.get("event_type")
            event_id = mapping.get("event_id")
            observed_types.append(event_type)
            observed_sequences.append(mapping.get("sequence"))
            activity_event_ids.append(event_id)
            event_ids.append(event_id)
            if event_type != expected_type:
                errors.append(f"{mapping_prefix}.event_type must be {expected_type}")
            if event_id != expected_event_id:
                errors.append(f"{mapping_prefix}.event_id must be deterministic for the event")
            if not _stable(event_id):
                errors.append(f"{mapping_prefix}.event_id must be stable lowercase text")
            if mapping.get("sequence") != mapping_index:
                errors.append(f"{mapping_prefix}.sequence must be contiguous from zero")
            if mapping.get("occurrence") != 1:
                errors.append(f"{mapping_prefix}.occurrence must be exactly one")
            if event_type in REWARD_EVENT_TYPES:
                if mapping.get("reward_id") != reward_id:
                    errors.append(f"{mapping_prefix}.reward_id must map to the activity reward")
                if mapping.get("reward_store_id") != REQUIRED_REWARD_STORE:
                    errors.append(f"{mapping_prefix}.reward_store_id must use the canonical reward store")
            else:
                if mapping.get("reward_id") is not None or mapping.get("reward_store_id") is not None:
                    errors.append(f"{mapping_prefix} must not map a reward before its reward event")
            if event_type in RETURN_EVENT_TYPES:
                if mapping.get("return_incentive_id") != incentive_id:
                    errors.append(f"{mapping_prefix}.return_incentive_id must map to the activity incentive")
                if mapping.get("return_target_id") != REQUIRED_RETURN_TARGET:
                    errors.append(f"{mapping_prefix}.return_target_id must be {REQUIRED_RETURN_TARGET}")
            elif mapping.get("return_incentive_id") is not None or mapping.get("return_target_id") is not None:
                errors.append(f"{mapping_prefix} must not map a return incentive before its return event")
        _unique(activity_event_ids, f"{prefix}.event_ids", errors)
        if tuple(observed_types) != EXPECTED_EVENT_TYPES:
            errors.append(f"{prefix}.mappings must retain authored event order")
        if observed_sequences != list(range(len(EXPECTED_EVENT_TYPES))):
            errors.append(f"{prefix}.mappings sequences must be contiguous from zero")
    if tuple(activity_ids) != REQUIRED_ACTIVITY_IDS:
        errors.append(f"{label}.activities must retain authored activity order")
    _unique(reward_ids, f"{label}.reward_ids", errors)
    _unique(incentive_ids, f"{label}.return_incentive_ids", errors)
    _unique(event_ids, f"{label}.event_ids", errors)

    authority = value.get("authority")
    if not isinstance(authority, dict):
        errors.append(f"{label}.authority must be an object")
    else:
        for key in ("activity", "objective", "reward", "reward_store", "return", "save", "network", "gameplay"):
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
        print(f"PLANETARY_EVENT_REWARD_MAPPING_INVALID: {exc}")
        return 1
    errors = validate_mapping(report)
    if errors:
        print("PLANETARY_EVENT_REWARD_MAPPING_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PLANETARY_EVENT_REWARD_MAPPING_VALID: detached event/reward mapping only")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
