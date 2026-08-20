#!/usr/bin/env python3
"""Validate detached planetary reward queue/grant/return duplicate guards.

For every authored activity, the ledger records one accepted queue, grant, and
return event plus rejected duplicate and stale attempts.  It is a contract
fixture only; no reward inventory or runtime authority is touched.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 1
EVIDENCE_SCOPE = "planetary_reward_queue_grant_return_duplicate_guards"
EVIDENCE_MODE = "detached_reward_guard_fixture"
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
GUARD_NAMES = ("queue", "grant", "return")


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _stable(value: Any) -> bool:
    return _text(value) and value == value.lower() and " " not in value and "__" not in value


def _unique(values: list[Any], label: str, errors: list[str]) -> None:
    if len(set(values)) != len(values):
        errors.append(f"{label} must not contain duplicates")


def validate_guards(value: Any, label: str = "ledger") -> list[str]:
    """Return blocking errors for one detached reward duplicate-guard ledger."""

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
        reward_ids.append(reward_id)
        if not _stable(reward_id):
            errors.append(f"{prefix}.reward_id must be stable lowercase text")
        guards = activity.get("guards")
        if not isinstance(guards, dict):
            errors.append(f"{prefix}.guards must be an object")
            guards = {}
        for guard_name in GUARD_NAMES:
            guard_prefix = f"{prefix}.guards.{guard_name}"
            guard = guards.get(guard_name)
            if not isinstance(guard, dict):
                errors.append(f"{guard_prefix} must be an object")
                continue
            event_id = guard.get("event_id")
            event_ids.append(event_id)
            expected_event_id = f"{activity_id}_{guard_name}" if _text(activity_id) else guard_name
            if event_id != expected_event_id:
                errors.append(f"{guard_prefix}.event_id must be deterministic for the guard")
            if not _stable(event_id):
                errors.append(f"{guard_prefix}.event_id must be stable lowercase text")
            if guard.get("first_generation") != 1 or guard.get("first_accepted") is not True:
                errors.append(f"{guard_prefix} must accept one generation-one event")
            if guard.get("duplicate_generation") != 1 or guard.get("duplicate_accepted") is not False or guard.get("duplicate_rejected") is not True:
                errors.append(f"{guard_prefix} must reject duplicate generation-one submission")
            if guard.get("stale_generation") != 0 or guard.get("stale_accepted") is not False or guard.get("stale_rejected") is not True:
                errors.append(f"{guard_prefix} must reject stale generation-zero submission")
            if guard.get("committed_once") is not True:
                errors.append(f"{guard_prefix}.committed_once must be true")
            if guard_name in {"queue", "grant"} and guard.get("reward_store_id") != REQUIRED_REWARD_STORE:
                errors.append(f"{guard_prefix}.reward_store_id must use the canonical reward store")
            if guard_name in {"queue", "grant"} and guard.get("reward_id") != reward_id:
                errors.append(f"{guard_prefix}.reward_id must match the activity reward")
            if guard_name == "return":
                if guard.get("return_incentive_id") != activity.get("return_incentive_id"):
                    errors.append(f"{guard_prefix}.return_incentive_id must match the activity incentive")
                if guard.get("return_target_id") != REQUIRED_RETURN_TARGET:
                    errors.append(f"{guard_prefix}.return_target_id must be {REQUIRED_RETURN_TARGET}")
        if not _stable(activity.get("return_incentive_id")) or not activity["return_incentive_id"].startswith("return_"):
            errors.append(f"{prefix}.return_incentive_id must begin with return_")
    if tuple(activity_ids) != REQUIRED_ACTIVITY_IDS:
        errors.append(f"{label}.activities must retain authored activity order")
    _unique(reward_ids, f"{label}.reward_ids", errors)
    _unique(event_ids, f"{label}.guard_event_ids", errors)

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
        print(f"PLANETARY_REWARD_GUARDS_INVALID: {exc}")
        return 1
    errors = validate_guards(report)
    if errors:
        print("PLANETARY_REWARD_GUARDS_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PLANETARY_REWARD_GUARDS_VALID: detached queue/grant/return guards only")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
