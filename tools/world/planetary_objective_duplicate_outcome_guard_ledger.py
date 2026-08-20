#!/usr/bin/env python3
"""Validate detached planetary objective duplicate-outcome guard evidence.

Each authored activity records one accepted outcome event and rejected
duplicate/stale submissions for objective completion, reward, and return.  The
ledger only proves the contract; it does not resolve objectives, grant items,
or mutate runtime state.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 1
EVIDENCE_SCOPE = "planetary_objective_duplicate_outcome_guards"
EVIDENCE_MODE = "detached_duplicate_outcome_ledger"
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
EXPECTED_OUTCOMES = (
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


def validate_ledger(value: Any, label: str = "ledger") -> list[str]:
    """Return blocking errors for one detached duplicate-outcome ledger."""

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
    objective_ids: list[Any] = []
    reward_ids: list[Any] = []
    outcome_event_ids: list[Any] = []
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
        objective_ids.append(objective_id)
        reward_ids.append(reward_id)
        for key, item in (("activity_id", activity_id), ("objective_id", objective_id), ("reward_id", reward_id)):
            if not _stable(item):
                errors.append(f"{prefix}.{key} must be stable lowercase text")
        if activity.get("activity_authority_id") not in EXISTING_ACTIVITY_AUTHORITIES:
            errors.append(f"{prefix}.activity_authority_id must use an existing activity authority")
        if activity.get("reward_authority_id") != REQUIRED_REWARD_AUTHORITY:
            errors.append(f"{prefix}.reward_authority_id must be {REQUIRED_REWARD_AUTHORITY}")
        if activity.get("reward_store_id") != REQUIRED_REWARD_STORE:
            errors.append(f"{prefix}.reward_store_id must use the one canonical reward store")
        if activity.get("return_authority_id") != REQUIRED_RETURN_AUTHORITY:
            errors.append(f"{prefix}.return_authority_id must be {REQUIRED_RETURN_AUTHORITY}")
        if activity.get("return_target_id") != REQUIRED_RETURN_TARGET:
            errors.append(f"{prefix}.return_target_id must be {REQUIRED_RETURN_TARGET}")
        if not _stable(activity.get("return_incentive_id")) or not activity["return_incentive_id"].startswith("return_"):
            errors.append(f"{prefix}.return_incentive_id must begin with return_")

        outcomes = activity.get("outcomes")
        if not isinstance(outcomes, list) or len(outcomes) != len(EXPECTED_OUTCOMES):
            errors.append(f"{prefix}.outcomes must contain exactly five ordered outcomes")
            outcomes = []
        observed_outcomes: list[Any] = []
        activity_event_ids: list[Any] = []
        for outcome_index, outcome in enumerate(outcomes):
            outcome_prefix = f"{prefix}.outcomes[{outcome_index}]"
            if not isinstance(outcome, dict):
                errors.append(f"{outcome_prefix} must be an object")
                continue
            expected_outcome = EXPECTED_OUTCOMES[outcome_index]
            outcome_type = outcome.get("type")
            first_event_id = outcome.get("first_event_id")
            duplicate_event_id = outcome.get("duplicate_event_id")
            stale_event_id = outcome.get("stale_event_id")
            observed_outcomes.append(outcome_type)
            for event_id in (first_event_id, duplicate_event_id, stale_event_id):
                activity_event_ids.append(event_id)
                outcome_event_ids.append(event_id)
                if not _stable(event_id):
                    errors.append(f"{outcome_prefix}.event IDs must be stable lowercase text")
            if outcome_type != expected_outcome:
                errors.append(f"{outcome_prefix}.type must be {expected_outcome}")
            if outcome.get("first_generation") != 1 or outcome.get("first_accepted") is not True:
                errors.append(f"{outcome_prefix} must accept exactly one first-generation event")
            if outcome.get("duplicate_generation") != 1 or outcome.get("duplicate_accepted") is not False or outcome.get("duplicate_rejected") is not True:
                errors.append(f"{outcome_prefix} must reject the duplicate generation-one event")
            if outcome.get("stale_generation") != 0 or outcome.get("stale_accepted") is not False or outcome.get("stale_rejected") is not True:
                errors.append(f"{outcome_prefix} must reject the stale generation-zero event")
            if outcome.get("committed_once") is not True:
                errors.append(f"{outcome_prefix}.committed_once must be true")
        _unique(activity_event_ids, f"{prefix}.outcome_event_ids", errors)
        if tuple(observed_outcomes) != EXPECTED_OUTCOMES:
            errors.append(f"{prefix}.outcomes must retain authored objective/reward/return order")
    if tuple(activity_ids) != REQUIRED_ACTIVITY_IDS:
        errors.append(f"{label}.activities must retain authored activity order")
    _unique(objective_ids, f"{label}.objective_ids", errors)
    _unique(reward_ids, f"{label}.reward_ids", errors)
    _unique(outcome_event_ids, f"{label}.outcome_event_ids", errors)

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
        print(f"PLANETARY_DUPLICATE_OUTCOME_INVALID: {exc}")
        return 1
    errors = validate_ledger(report)
    if errors:
        print("PLANETARY_DUPLICATE_OUTCOME_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PLANETARY_DUPLICATE_OUTCOME_VALID: detached duplicate guard evidence only")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
