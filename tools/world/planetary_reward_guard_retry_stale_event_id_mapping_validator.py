#!/usr/bin/env python3
"""Validate detached planetary reward retry/stale event-ID mappings.

Each authored reward maps one retry guard ID to a valid generation advance and
one stale guard ID to a rejected generation mismatch.  This evidence record
does not grant inventory or own reward/recovery runtime authority.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 1
EVIDENCE_SCOPE = "planetary_reward_guard_retry_stale_event_id_mapping"
EVIDENCE_MODE = "detached_reward_retry_stale_mapping"
REQUIRED_WORLD_ID = "ember_moon"
REQUIRED_REWARD_AUTHORITY = "game_flow_reward_authority"
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


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _stable(value: Any) -> bool:
    return _text(value) and value == value.lower() and " " not in value and "__" not in value


def _unique(values: list[Any], label: str, errors: list[str]) -> None:
    if len(set(values)) != len(values):
        errors.append(f"{label} must not contain duplicates")


def validate_mapping(value: Any, label: str = "mapping") -> list[str]:
    """Return blocking errors for one detached retry/stale ID mapping."""

    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    if value.get("evidence_scope") != EVIDENCE_SCOPE:
        errors.append(f"{label}.evidence_scope must be {EVIDENCE_SCOPE}")
    if value.get("evidence_mode") != EVIDENCE_MODE:
        errors.append(f"{label}.evidence_mode must be {EVIDENCE_MODE}")
    for key in ("runtime_authority", "reward_inventory", "reward_runtime", "native_claims"):
        if value.get(key) is not False:
            errors.append(f"{label}.{key} must be false")
    if value.get("world_id") != REQUIRED_WORLD_ID:
        errors.append(f"{label}.world_id must be {REQUIRED_WORLD_ID}")
    if value.get("reward_store_id") != REQUIRED_REWARD_STORE:
        errors.append(f"{label}.reward_store_id must use the one canonical reward store")
    if not _text(value.get("source_revision")):
        errors.append(f"{label}.source_revision is required")

    activities = value.get("activities")
    if not isinstance(activities, list) or len(activities) != len(REQUIRED_ACTIVITY_IDS):
        errors.append(f"{label}.activities must contain exactly five authored activities")
        activities = []
    activity_ids: list[Any] = []
    reward_ids: list[Any] = []
    guard_ids: list[Any] = []
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
        reward_id = activity.get("reward_id")
        reward_ids.append(reward_id)
        if not _stable(reward_id):
            errors.append(f"{prefix}.reward_id must be stable lowercase text")
        for guard_name, expected_suffix, expected_generation, expected_accepted, expected_rejected in (
            ("retry", "reward_retry_g2", 2, True, False),
            ("stale", "reward_stale_g0", 0, False, True),
        ):
            guard_prefix = f"{prefix}.{guard_name}_guard"
            guard = activity.get(f"{guard_name}_guard")
            if not isinstance(guard, dict):
                errors.append(f"{guard_prefix} must be an object")
                continue
            event_id = guard.get("event_id")
            guard_ids.append(event_id)
            expected_event_id = f"{activity_id}_{expected_suffix}" if _text(activity_id) else expected_suffix
            if event_id != expected_event_id:
                errors.append(f"{guard_prefix}.event_id must be deterministic for the guard")
            if not _stable(event_id):
                errors.append(f"{guard_prefix}.event_id must be stable lowercase text")
            if guard.get("submitted_generation") != expected_generation:
                errors.append(f"{guard_prefix}.submitted_generation must be {expected_generation}")
            if guard.get("accepted") is not expected_accepted:
                errors.append(f"{guard_prefix}.accepted has an invalid generation outcome")
            if guard.get("rejected") is not expected_rejected:
                errors.append(f"{guard_prefix}.rejected has an invalid generation outcome")
            if guard.get("reward_id") != reward_id:
                errors.append(f"{guard_prefix}.reward_id must match the activity reward")
            if guard.get("reward_store_id") != REQUIRED_REWARD_STORE:
                errors.append(f"{guard_prefix}.reward_store_id must use the canonical reward store")
            if guard.get("committed_once") is not True:
                errors.append(f"{guard_prefix}.committed_once must be true")
            if guard_name == "retry":
                if guard.get("source_generation") != 1 or guard.get("current_generation") != 2:
                    errors.append(f"{guard_prefix} must map source generation one to current generation two")
            else:
                if guard.get("source_generation") != 0 or guard.get("current_generation") != 2:
                    errors.append(f"{guard_prefix} must map stale generation zero to current generation two")
                if guard.get("reason") != "stale_generation":
                    errors.append(f"{guard_prefix}.reason must be stale_generation")
        
    if tuple(activity_ids) != REQUIRED_ACTIVITY_IDS:
        errors.append(f"{label}.activities must retain authored activity order")
    _unique(reward_ids, f"{label}.reward_ids", errors)
    _unique(guard_ids, f"{label}.guard_ids", errors)

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
    parser.add_argument("mapping", type=Path)
    args = parser.parse_args(argv)
    try:
        report = json.loads(args.mapping.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        print(f"PLANETARY_REWARD_RETRY_STALE_INVALID: {exc}")
        return 1
    errors = validate_mapping(report)
    if errors:
        print("PLANETARY_REWARD_RETRY_STALE_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PLANETARY_REWARD_RETRY_STALE_VALID: detached retry/stale ID mapping only")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
