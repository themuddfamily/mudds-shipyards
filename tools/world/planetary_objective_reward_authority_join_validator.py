#!/usr/bin/env python3
"""Validate detached planetary objective/reward authority joins.

Each authored activity is joined to an existing activity authority, the one
existing GameFlow reward authority/store, and the landing return authority.
This validator owns no objective state, reward inventory, recovery flow, or
runtime/native execution.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 1
EVIDENCE_SCOPE = "planetary_objective_reward_authority_join"
EVIDENCE_MODE = "detached_contract_fixture"
REQUIRED_WORLD_ID = "ember_moon"
REQUIRED_RETURN_TARGET = "mudds_shipyards"
REQUIRED_REWARD_AUTHORITY = "game_flow_reward_authority"
REQUIRED_REWARD_STORE = "game_flow_reward_store"
REQUIRED_RECOVERY_AUTHORITY = "planetary_landing_return_contract"
EXISTING_ACTIVITY_AUTHORITIES = {
    "activity_director",
    "cargo_delivery_activity",
    "timed_checkpoint_race",
    "convoy_escort_activity",
}
EXISTING_RECOVERY_IDS = {
    "return_to_landed_ship",
    "abort_to_orbit_return",
    "reset_at_start_beacon",
    "recover_convoy_at_return_beacon",
}
REQUIRED_ACTIVITY_IDS = (
    "ember_beacon_survey",
    "ember_caldera_patrol",
    "ember_kit_cargo_run",
    "ember_checkpoint_race",
    "ember_convoy_escort",
)


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _stable(value: Any) -> bool:
    return _text(value) and value == value.lower() and " " not in value and "__" not in value


def _unique(values: list[Any], label: str, errors: list[str]) -> None:
    if len(set(values)) != len(values):
        errors.append(f"{label} must not contain duplicate IDs")


def validate_join(value: Any, label: str = "join") -> list[str]:
    """Return blocking errors for one detached objective authority join."""

    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    if value.get("evidence_scope") != EVIDENCE_SCOPE:
        errors.append(f"{label}.evidence_scope must be {EVIDENCE_SCOPE}")
    if value.get("evidence_mode") != EVIDENCE_MODE:
        errors.append(f"{label}.evidence_mode must be {EVIDENCE_MODE}")
    for key in ("runtime_wired", "objective_runtime", "reward_inventory", "recovery_runtime", "native_claims"):
        if value.get(key) is not False:
            errors.append(f"{label}.{key} must be false")
    if value.get("world_id") != REQUIRED_WORLD_ID:
        errors.append(f"{label}.world_id must be {REQUIRED_WORLD_ID}")
    if value.get("return_target_id") != REQUIRED_RETURN_TARGET:
        errors.append(f"{label}.return_target_id must be {REQUIRED_RETURN_TARGET}")
    if not _text(value.get("source_revision")):
        errors.append(f"{label}.source_revision is required")

    authorities = value.get("authorities")
    if not isinstance(authorities, dict):
        errors.append(f"{label}.authorities must be an object")
    else:
        for key, expected in (
            ("reward", REQUIRED_REWARD_AUTHORITY),
            ("reward_store", REQUIRED_REWARD_STORE),
            ("recovery", REQUIRED_RECOVERY_AUTHORITY),
        ):
            if authorities.get(key) != expected:
                errors.append(f"{label}.authorities.{key} must be {expected}")
        if authorities.get("owns_reward_store") is not False:
            errors.append(f"{label}.authorities.owns_reward_store must be false")

    activities = value.get("activities")
    if not isinstance(activities, list) or len(activities) != len(REQUIRED_ACTIVITY_IDS):
        errors.append(f"{label}.activities must contain exactly five authored activities")
        activities = []
    activity_ids: list[str] = []
    objective_ids: list[str] = []
    reward_ids: list[str] = []
    incentive_ids: list[str] = []
    reward_store_ids: list[str] = []
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
        reward_id = activity.get("reward_id")
        reward_ids.append(reward_id)
        incentive_id = activity.get("return_incentive_id")
        incentive_ids.append(incentive_id)
        store_id = activity.get("reward_store_id")
        reward_store_ids.append(store_id)
        for key, value_to_check in (
            ("activity_id", activity_id), ("objective_id", objective_id),
            ("reward_id", reward_id), ("return_incentive_id", incentive_id),
        ):
            if not _stable(value_to_check):
                errors.append(f"{prefix}.{key} must be lowercase stable text")
        if activity.get("activity_authority_id") not in EXISTING_ACTIVITY_AUTHORITIES:
            errors.append(f"{prefix}.activity_authority_id must name an existing activity authority")
        if activity.get("reward_authority_id") != REQUIRED_REWARD_AUTHORITY:
            errors.append(f"{prefix}.reward_authority_id must be {REQUIRED_REWARD_AUTHORITY}")
        if store_id != REQUIRED_REWARD_STORE:
            errors.append(f"{prefix}.reward_store_id must use the one existing reward store")
        if not _text(incentive_id) or not incentive_id.startswith("return_"):
            errors.append(f"{prefix}.return_incentive_id must begin with return_")
        if activity.get("return_target_id") != REQUIRED_RETURN_TARGET:
            errors.append(f"{prefix}.return_target_id must be {REQUIRED_RETURN_TARGET}")
        if activity.get("recovery_authority_id") != REQUIRED_RECOVERY_AUTHORITY:
            errors.append(f"{prefix}.recovery_authority_id must be {REQUIRED_RECOVERY_AUTHORITY}")
        if activity.get("recovery_id") not in EXISTING_RECOVERY_IDS:
            errors.append(f"{prefix}.recovery_id must name an existing recoverable state")
        if activity.get("objective_completed_once") is not True:
            errors.append(f"{prefix}.objective_completed_once must be true")
        if activity.get("reward_granted_once") is not True:
            errors.append(f"{prefix}.reward_granted_once must be true")
    if tuple(activity_ids) != REQUIRED_ACTIVITY_IDS:
        errors.append(f"{label}.activities must retain the authored activity order")
    _unique(objective_ids, f"{label}.objective_ids", errors)
    _unique(reward_ids, f"{label}.reward_ids", errors)
    _unique(incentive_ids, f"{label}.return_incentive_ids", errors)
    if set(reward_store_ids) != {REQUIRED_REWARD_STORE}:
        errors.append(f"{label}.reward_store_ids must contain one canonical store only")

    evidence = value.get("evidence")
    if not isinstance(evidence, dict):
        errors.append(f"{label}.evidence must be an object")
    else:
        if evidence.get("historical_claim") is not False or evidence.get("procedural_generation") is not False:
            errors.append(f"{label}.evidence must make no historical or procedural claim")
        references = evidence.get("references")
        if not isinstance(references, list) or not references or not all(_text(item) and item.startswith("res://") for item in references):
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
    parser.add_argument("join", type=Path)
    args = parser.parse_args(argv)
    try:
        report = json.loads(args.join.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        print(f"PLANETARY_OBJECTIVE_REWARD_JOIN_INVALID: {exc}")
        return 1
    errors = validate_join(report)
    if errors:
        print("PLANETARY_OBJECTIVE_REWARD_JOIN_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PLANETARY_OBJECTIVE_REWARD_JOIN_VALID: detached authority join only")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
