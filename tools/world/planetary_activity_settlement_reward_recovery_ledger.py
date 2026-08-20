#!/usr/bin/env python3
"""Validate an authored planetary activity/settlement reward ledger.

The ledger joins settlement landmarks, activity objectives, reward keys,
return incentives, and recoverable failure routes.  It is a detached evidence
record: no objective is resolved, reward is granted, or recovery state is
mutated here.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 1
EVIDENCE_SCOPE = "planetary_activity_settlement_reward_recovery"
EVIDENCE_MODE = "detached_ledger_fixture"
REQUIRED_WORLD_ID = "ember_moon"
REQUIRED_SETTLEMENT_ID = "ember_caldera_settlement"
REQUIRED_RETURN_TARGET = "mudds_shipyards"
REQUIRED_REWARD_STORE = "game_flow_reward_store"
REQUIRED_REWARD_AUTHORITY = "game_flow_reward_authority"
REQUIRED_RECOVERY_AUTHORITY = "planetary_landing_return_contract"
REQUIRED_ACTIVITY_IDS = (
    "ember_settlement_supply_run",
    "ember_relay_repair",
    "ember_shelter_recovery",
)
EXISTING_ACTIVITY_AUTHORITIES = {"activity_director", "cargo_delivery_activity"}
EXISTING_RECOVERY_IDS = {"return_to_landed_ship", "recover_at_surface_shelter", "abort_to_orbit_return"}
REQUIRED_LEDGER_EVENTS = ("objective_completed", "reward_queued", "return_incentive_presented", "recovery_registered", "settlement_return")


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _stable(value: Any) -> bool:
    return _text(value) and value == value.lower() and " " not in value and "__" not in value


def _unique(values: list[Any], label: str, errors: list[str]) -> None:
    if len(set(values)) != len(values):
        errors.append(f"{label} must not contain duplicate IDs")


def validate_ledger(value: Any, label: str = "ledger") -> list[str]:
    """Return blocking errors for one detached settlement reward ledger."""

    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    if value.get("evidence_scope") != EVIDENCE_SCOPE:
        errors.append(f"{label}.evidence_scope must be {EVIDENCE_SCOPE}")
    if value.get("evidence_mode") != EVIDENCE_MODE:
        errors.append(f"{label}.evidence_mode must be {EVIDENCE_MODE}")
    for key in ("runtime_wired", "reward_inventory", "objective_resolution", "recovery_mutation", "native_claims"):
        if value.get(key) is not False:
            errors.append(f"{label}.{key} must be false")
    for key, expected in (("world_id", REQUIRED_WORLD_ID), ("settlement_id", REQUIRED_SETTLEMENT_ID), ("return_target_id", REQUIRED_RETURN_TARGET)):
        if value.get(key) != expected:
            errors.append(f"{label}.{key} must be {expected}")
    if not _text(value.get("source_revision")):
        errors.append(f"{label}.source_revision is required")

    landmarks = value.get("landmarks")
    if not isinstance(landmarks, dict) or len(landmarks) < 4:
        errors.append(f"{label}.landmarks must contain at least four authored landmarks")
        landmarks = {}
    else:
        for landmark_id, route_id in landmarks.items():
            if not _stable(landmark_id) or not _stable(route_id):
                errors.append(f"{label}.landmarks IDs and routes must be stable lowercase text")

    activities = value.get("activities")
    if not isinstance(activities, list) or len(activities) != len(REQUIRED_ACTIVITY_IDS):
        errors.append(f"{label}.activities must contain exactly three settlement activities")
        activities = []
    activity_ids: list[str] = []
    reward_ids: list[str] = []
    recovery_ids: list[str] = []
    incentive_ids: list[str] = []
    store_ids: list[str] = []
    for index, activity in enumerate(activities):
        prefix = f"{label}.activities[{index}]"
        if not isinstance(activity, dict):
            errors.append(f"{prefix} must be an object")
            continue
        activity_id = activity.get("activity_id")
        activity_ids.append(activity_id)
        if activity_id != REQUIRED_ACTIVITY_IDS[index]:
            errors.append(f"{prefix}.activity_id must be {REQUIRED_ACTIVITY_IDS[index]}")
        for key in ("objective_id", "reward_id", "recovery_id", "return_incentive_id", "start_landmark_id", "finish_landmark_id", "activity_route_id", "return_route_id"):
            if not _stable(activity.get(key)):
                errors.append(f"{prefix}.{key} must be stable lowercase text")
        reward_ids.append(activity.get("reward_id"))
        recovery_ids.append(activity.get("recovery_id"))
        incentive_ids.append(activity.get("return_incentive_id"))
        store_ids.append(activity.get("reward_store_id"))
        if activity.get("start_landmark_id") not in landmarks or activity.get("finish_landmark_id") not in landmarks:
            errors.append(f"{prefix} must reference declared settlement landmarks")
        if activity.get("activity_authority_id") not in EXISTING_ACTIVITY_AUTHORITIES:
            errors.append(f"{prefix}.activity_authority_id must use an existing activity authority")
        if activity.get("reward_authority_id") != REQUIRED_REWARD_AUTHORITY:
            errors.append(f"{prefix}.reward_authority_id must be {REQUIRED_REWARD_AUTHORITY}")
        if activity.get("reward_store_id") != REQUIRED_REWARD_STORE:
            errors.append(f"{prefix}.reward_store_id must use the one canonical reward store")
        if not activity.get("return_incentive_id", "").startswith("return_"):
            errors.append(f"{prefix}.return_incentive_id must begin with return_")
        if activity.get("return_target_id") != REQUIRED_RETURN_TARGET:
            errors.append(f"{prefix}.return_target_id must be {REQUIRED_RETURN_TARGET}")
        if activity.get("recovery_id") not in EXISTING_RECOVERY_IDS:
            errors.append(f"{prefix}.recovery_id must use an existing recovery state")
        if activity.get("recovery_authority_id") != REQUIRED_RECOVERY_AUTHORITY:
            errors.append(f"{prefix}.recovery_authority_id must be {REQUIRED_RECOVERY_AUTHORITY}")
        if activity.get("reward_grant_once") is not True:
            errors.append(f"{prefix}.reward_grant_once must be true")
        if activity.get("retryable") is not True:
            errors.append(f"{prefix}.retryable must be true")
    if tuple(activity_ids) != REQUIRED_ACTIVITY_IDS:
        errors.append(f"{label}.activities must retain authored settlement order")
    _unique(reward_ids, f"{label}.reward_ids", errors)
    _unique(recovery_ids, f"{label}.recovery_ids", errors)
    _unique(incentive_ids, f"{label}.return_incentive_ids", errors)
    if set(store_ids) != {REQUIRED_REWARD_STORE}:
        errors.append(f"{label}.reward_store_ids must contain exactly one canonical store")

    ledger_events = value.get("ledger_events")
    if not isinstance(ledger_events, list):
        errors.append(f"{label}.ledger_events must be an array")
    else:
        event_ids: list[str] = []
        sequences: list[int] = []
        for index, event in enumerate(ledger_events):
            prefix = f"{label}.ledger_events[{index}]"
            if not isinstance(event, dict):
                errors.append(f"{prefix} must be an object")
                continue
            event_id = event.get("id")
            event_ids.append(event_id)
            if not _stable(event_id):
                errors.append(f"{prefix}.id must be stable lowercase text")
            sequence = event.get("sequence")
            if not isinstance(sequence, int) or isinstance(sequence, bool) or sequence < 0:
                errors.append(f"{prefix}.sequence must be a non-negative integer")
            else:
                sequences.append(sequence)
            if event.get("committed_once") is not True:
                errors.append(f"{prefix}.committed_once must be true")
        if tuple(event_ids) != REQUIRED_LEDGER_EVENTS:
            errors.append(f"{label}.ledger_events must contain the exact ordered outcome sequence")
        if sequences != list(range(len(sequences))):
            errors.append(f"{label}.ledger_events sequences must be contiguous from zero")

    evidence = value.get("evidence")
    if not isinstance(evidence, dict):
        errors.append(f"{label}.evidence must be an object")
    else:
        if evidence.get("historical_claim") is not False or evidence.get("procedural_generation") is not False:
            errors.append(f"{label}.evidence must make no historical or procedural claim")
        refs = evidence.get("references")
        if not isinstance(refs, list) or not refs or not all(_text(item) and item.startswith("res://") for item in refs):
            errors.append(f"{label}.evidence.references must contain res:// paths")

    authority = value.get("authority")
    if not isinstance(authority, dict):
        errors.append(f"{label}.authority must be an object")
    else:
        for key in ("objective", "activity", "reward", "reward_store", "recovery", "save", "network", "gameplay"):
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
        print(f"PLANETARY_SETTLEMENT_REWARD_LEDGER_INVALID: {exc}")
        return 1
    errors = validate_ledger(report)
    if errors:
        print("PLANETARY_SETTLEMENT_REWARD_LEDGER_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PLANETARY_SETTLEMENT_REWARD_LEDGER_VALID: detached ledger only")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
