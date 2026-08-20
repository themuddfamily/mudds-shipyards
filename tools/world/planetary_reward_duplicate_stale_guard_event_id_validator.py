#!/usr/bin/env python3
"""Validate detached planetary reward duplicate/stale guard event IDs.

The catalog gives every authored reward guard submission a deterministic ID:
initial, duplicate, retry, duplicate-retry, and stale.  It checks generation
and outcome metadata without granting inventory or owning reward runtime.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 1
EVIDENCE_SCOPE = "planetary_reward_duplicate_stale_guard_event_ids"
EVIDENCE_MODE = "detached_reward_guard_event_catalog"
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
EXPECTED_GUARDS = (
    ("initial", 1, True, False, False, "reward_granted_g1"),
    ("duplicate_initial", 1, False, True, False, "reward_granted_duplicate_g1"),
    ("retry", 2, True, False, False, "reward_granted_g2"),
    ("duplicate_retry", 2, False, True, False, "reward_granted_duplicate_g2"),
    ("stale", 0, False, False, True, "reward_granted_stale_g0"),
)


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _stable(value: Any) -> bool:
    return _text(value) and value == value.lower() and " " not in value and "__" not in value


def _unique(values: list[Any], label: str, errors: list[str]) -> None:
    if len(set(values)) != len(values):
        errors.append(f"{label} must not contain duplicates")


def validate_catalog(value: Any, label: str = "catalog") -> list[str]:
    """Return blocking errors for one detached reward guard-ID catalog."""

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
    if value.get("guard_count") != len(REQUIRED_ACTIVITY_IDS) * len(EXPECTED_GUARDS):
        errors.append(f"{label}.guard_count must be exactly twenty-five")
    if not _text(value.get("source_revision")):
        errors.append(f"{label}.source_revision is required")

    activities = value.get("activities")
    if not isinstance(activities, list) or len(activities) != len(REQUIRED_ACTIVITY_IDS):
        errors.append(f"{label}.activities must contain exactly five authored activities")
        activities = []
    activity_ids: list[Any] = []
    reward_ids: list[Any] = []
    all_guard_ids: list[Any] = []
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
        guards = activity.get("guards")
        if not isinstance(guards, list) or len(guards) != len(EXPECTED_GUARDS):
            errors.append(f"{prefix}.guards must contain exactly five ordered guards")
            guards = []
        observed_kinds: list[Any] = []
        activity_guard_ids: list[Any] = []
        for guard_index, guard in enumerate(guards):
            guard_prefix = f"{prefix}.guards[{guard_index}]"
            if not isinstance(guard, dict):
                errors.append(f"{guard_prefix} must be an object")
                continue
            expected_kind, expected_generation, expected_accepted, expected_duplicate, expected_stale, suffix = EXPECTED_GUARDS[guard_index]
            kind = guard.get("kind")
            event_id = guard.get("event_id")
            expected_event_id = f"{activity_id}_{suffix}" if _text(activity_id) else suffix
            observed_kinds.append(kind)
            activity_guard_ids.append(event_id)
            all_guard_ids.append(event_id)
            observed_count += 1
            if kind != expected_kind:
                errors.append(f"{guard_prefix}.kind must be {expected_kind}")
            if event_id != expected_event_id:
                errors.append(f"{guard_prefix}.event_id must be deterministic for its guard")
            if not _stable(event_id):
                errors.append(f"{guard_prefix}.event_id must be stable lowercase text")
            if guard.get("generation") != expected_generation:
                errors.append(f"{guard_prefix}.generation must be {expected_generation}")
            if guard.get("accepted") is not expected_accepted:
                errors.append(f"{guard_prefix}.accepted has an invalid guard outcome")
            if guard.get("duplicate_rejected") is not expected_duplicate:
                errors.append(f"{guard_prefix}.duplicate_rejected has an invalid guard outcome")
            if guard.get("stale_rejected") is not expected_stale:
                errors.append(f"{guard_prefix}.stale_rejected has an invalid guard outcome")
            if guard.get("reward_id") != reward_id:
                errors.append(f"{guard_prefix}.reward_id must match the activity reward")
            if guard.get("reward_store_id") != REQUIRED_REWARD_STORE:
                errors.append(f"{guard_prefix}.reward_store_id must use the canonical reward store")
            if guard.get("committed_once") is not True:
                errors.append(f"{guard_prefix}.committed_once must be true")
        _unique(activity_guard_ids, f"{prefix}.guard_ids", errors)
        if tuple(observed_kinds) != tuple(item[0] for item in EXPECTED_GUARDS):
            errors.append(f"{prefix}.guards must retain authored guard order")
    if tuple(activity_ids) != REQUIRED_ACTIVITY_IDS:
        errors.append(f"{label}.activities must retain authored activity order")
    _unique(reward_ids, f"{label}.reward_ids", errors)
    _unique(all_guard_ids, f"{label}.guard_ids", errors)
    if observed_count != value.get("guard_count"):
        errors.append(f"{label}.guard_count must match authored guard records")

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
        print(f"PLANETARY_REWARD_GUARD_IDS_INVALID: {exc}")
        return 1
    errors = validate_catalog(report)
    if errors:
        print("PLANETARY_REWARD_GUARD_IDS_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PLANETARY_REWARD_GUARD_IDS_VALID: detached reward guard IDs only")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
