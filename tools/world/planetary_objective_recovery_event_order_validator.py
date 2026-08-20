#!/usr/bin/env python3
"""Validate detached planetary objective recovery event ordering.

The record proves an authored, generation-fenced failure/recovery/retry/return
sequence for each Ember activity.  It is evidence only: no event is emitted,
objective state is changed, or player movement is performed here.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 1
EVIDENCE_SCOPE = "planetary_objective_recovery_event_order"
EVIDENCE_MODE = "detached_recovery_event_order"
REQUIRED_WORLD_ID = "ember_moon"
REQUIRED_RETURN_TARGET = "mudds_shipyards"
REQUIRED_RECOVERY_AUTHORITY = "planetary_landing_return_contract"
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
RECOVERY_CONTRACTS = {
    "return_to_landed_ship": ("ember_landed_ship_beacon", "landed_ship"),
    "abort_to_orbit_return": ("ember_orbit_return_beacon", "orbit_return"),
    "reset_at_start_beacon": ("ember_start_beacon", "start_beacon"),
    "recover_convoy_at_return_beacon": ("ember_convoy_return_beacon", "convoy_return_beacon"),
}
EXPECTED_EVENTS = (
    "objective_failed",
    "recovery_requested",
    "recovery_accepted",
    "return_beacon_arrived",
    "retry_started",
    "objective_retried",
    "return_presented",
    "returned",
)
EXPECTED_GENERATIONS = (1, 1, 1, 1, 2, 2, 2, 2)


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _stable(value: Any) -> bool:
    return _text(value) and value == value.lower() and " " not in value and "__" not in value


def _unique(values: list[Any], label: str, errors: list[str]) -> None:
    if len(set(values)) != len(values):
        errors.append(f"{label} must not contain duplicates")


def validate_order(value: Any, label: str = "ledger") -> list[str]:
    """Return blocking errors for one detached recovery event-order ledger."""

    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    if value.get("evidence_scope") != EVIDENCE_SCOPE:
        errors.append(f"{label}.evidence_scope must be {EVIDENCE_SCOPE}")
    if value.get("evidence_mode") != EVIDENCE_MODE:
        errors.append(f"{label}.evidence_mode must be {EVIDENCE_MODE}")
    for key in ("runtime_authority", "objective_runtime", "recovery_runtime", "movement_runtime", "native_claims"):
        if value.get(key) is not False:
            errors.append(f"{label}.{key} must be false")
    if value.get("world_id") != REQUIRED_WORLD_ID:
        errors.append(f"{label}.world_id must be {REQUIRED_WORLD_ID}")
    if value.get("return_target_id") != REQUIRED_RETURN_TARGET:
        errors.append(f"{label}.return_target_id must be {REQUIRED_RETURN_TARGET}")
    if not _text(value.get("source_revision")):
        errors.append(f"{label}.source_revision is required")

    activities = value.get("activities")
    if not isinstance(activities, list) or len(activities) != len(REQUIRED_ACTIVITY_IDS):
        errors.append(f"{label}.activities must contain exactly five authored activities")
        activities = []
    activity_ids: list[Any] = []
    objective_ids: list[Any] = []
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
        objective_ids.append(objective_id)
        if not _stable(objective_id):
            errors.append(f"{prefix}.objective_id must be stable lowercase text")
        if activity.get("activity_authority_id") not in EXISTING_ACTIVITY_AUTHORITIES:
            errors.append(f"{prefix}.activity_authority_id must use an existing activity authority")
        if activity.get("recovery_authority_id") != REQUIRED_RECOVERY_AUTHORITY:
            errors.append(f"{prefix}.recovery_authority_id must be {REQUIRED_RECOVERY_AUTHORITY}")
        recovery_id = activity.get("recovery_id")
        if recovery_id not in RECOVERY_CONTRACTS:
            errors.append(f"{prefix}.recovery_id must use an existing recovery contract")
        else:
            expected_beacon, expected_target = RECOVERY_CONTRACTS[recovery_id]
            if activity.get("return_beacon_id") != expected_beacon:
                errors.append(f"{prefix}.return_beacon_id must match its recovery contract")
            if activity.get("recovery_target") != expected_target:
                errors.append(f"{prefix}.recovery_target must match its recovery contract")
        if not _stable(activity.get("return_route_id")):
            errors.append(f"{prefix}.return_route_id must be stable lowercase text")
        if activity.get("return_target_id") != REQUIRED_RETURN_TARGET:
            errors.append(f"{prefix}.return_target_id must be {REQUIRED_RETURN_TARGET}")
        for key in ("stale_event_rejected", "duplicate_recovery_rejected", "retry_once", "return_once"):
            if activity.get(key) is not True:
                errors.append(f"{prefix}.{key} must be true")

        events = activity.get("events")
        if not isinstance(events, list) or len(events) != len(EXPECTED_EVENTS):
            errors.append(f"{prefix}.events must contain exactly eight ordered events")
            events = []
        observed_types: list[Any] = []
        observed_sequences: list[Any] = []
        observed_generations: list[Any] = []
        activity_event_ids: list[Any] = []
        for event_index, event in enumerate(events):
            event_prefix = f"{prefix}.events[{event_index}]"
            if not isinstance(event, dict):
                errors.append(f"{event_prefix} must be an object")
                continue
            event_type = event.get("type")
            event_id = event.get("event_id")
            observed_types.append(event_type)
            observed_sequences.append(event.get("sequence"))
            observed_generations.append(event.get("generation"))
            activity_event_ids.append(event_id)
            event_ids.append(event_id)
            if event_type != EXPECTED_EVENTS[event_index]:
                errors.append(f"{event_prefix}.type must be {EXPECTED_EVENTS[event_index]}")
            if not _stable(event_id):
                errors.append(f"{event_prefix}.event_id must be stable lowercase text")
            if event.get("sequence") != event_index:
                errors.append(f"{event_prefix}.sequence must be contiguous from zero")
            if event.get("generation") != EXPECTED_GENERATIONS[event_index]:
                errors.append(f"{event_prefix}.generation must match the authored retry boundary")
            if event.get("committed_once") is not True:
                errors.append(f"{event_prefix}.committed_once must be true")
        _unique(activity_event_ids, f"{prefix}.event_ids", errors)
        if tuple(observed_types) != EXPECTED_EVENTS:
            errors.append(f"{prefix}.events must retain the authored recovery order")
        if observed_sequences != list(range(len(EXPECTED_EVENTS))):
            errors.append(f"{prefix}.events sequences must be contiguous from zero")
        if tuple(observed_generations) != EXPECTED_GENERATIONS:
            errors.append(f"{prefix}.events generations must remain fenced across retry")
    if tuple(activity_ids) != REQUIRED_ACTIVITY_IDS:
        errors.append(f"{label}.activities must retain authored activity order")
    _unique(objective_ids, f"{label}.objective_ids", errors)
    _unique(event_ids, f"{label}.event_ids", errors)

    authority = value.get("authority")
    if not isinstance(authority, dict):
        errors.append(f"{label}.authority must be an object")
    else:
        for key in ("activity", "objective", "recovery", "movement", "landing", "save", "network", "gameplay"):
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
        print(f"PLANETARY_RECOVERY_EVENT_ORDER_INVALID: {exc}")
        return 1
    errors = validate_order(report)
    if errors:
        print("PLANETARY_RECOVERY_EVENT_ORDER_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PLANETARY_RECOVERY_EVENT_ORDER_VALID: detached event ordering only")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
