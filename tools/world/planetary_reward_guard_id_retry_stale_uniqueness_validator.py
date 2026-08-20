#!/usr/bin/env python3
"""Validate reward-keyed retry/stale guard ID uniqueness evidence.

The compact catalog maps each authored reward to one retry guard ID and one
stale guard ID.  It is a detached contract fixture and cannot grant rewards
or mutate runtime state.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 1
EVIDENCE_SCOPE = "planetary_reward_guard_id_retry_stale_uniqueness"
EVIDENCE_MODE = "detached_reward_keyed_guard_catalog"
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


def validate_catalog(value: Any, label: str = "catalog") -> list[str]:
    """Return blocking errors for one reward-keyed guard-ID catalog."""

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
    if value.get("guard_id_count") != 10:
        errors.append(f"{label}.guard_id_count must be exactly ten")
    if not _text(value.get("source_revision")):
        errors.append(f"{label}.source_revision is required")

    rewards = value.get("rewards")
    if not isinstance(rewards, list) or len(rewards) != len(REQUIRED_ACTIVITY_IDS):
        errors.append(f"{label}.rewards must contain exactly five authored rewards")
        rewards = []
    activity_ids: list[Any] = []
    reward_ids: list[Any] = []
    guard_ids: list[Any] = []
    for index, reward in enumerate(rewards):
        prefix = f"{label}.rewards[{index}]"
        if not isinstance(reward, dict):
            errors.append(f"{prefix} must be an object")
            continue
        activity_id = reward.get("activity_id")
        activity_ids.append(activity_id)
        if activity_id != REQUIRED_ACTIVITY_IDS[index]:
            errors.append(f"{prefix}.activity_id must be {REQUIRED_ACTIVITY_IDS[index]}")
        if reward.get("activity_authority_id") not in EXISTING_ACTIVITY_AUTHORITIES:
            errors.append(f"{prefix}.activity_authority_id must use an existing activity authority")
        if reward.get("reward_authority_id") != REQUIRED_REWARD_AUTHORITY:
            errors.append(f"{prefix}.reward_authority_id must be {REQUIRED_REWARD_AUTHORITY}")
        reward_id = reward.get("reward_id")
        reward_ids.append(reward_id)
        if not _stable(reward_id):
            errors.append(f"{prefix}.reward_id must be stable lowercase text")
        retry_id = reward.get("retry_guard_id")
        stale_id = reward.get("stale_guard_id")
        guard_ids.extend((retry_id, stale_id))
        if retry_id != f"{activity_id}_reward_retry_g2":
            errors.append(f"{prefix}.retry_guard_id must be deterministic")
        if stale_id != f"{activity_id}_reward_stale_g0":
            errors.append(f"{prefix}.stale_guard_id must be deterministic")
        for key, guard_id in (("retry_guard_id", retry_id), ("stale_guard_id", stale_id)):
            if not _stable(guard_id):
                errors.append(f"{prefix}.{key} must be stable lowercase text")
        if reward.get("retry_generation") != 2 or reward.get("retry_accepted") is not True:
            errors.append(f"{prefix} must accept retry generation two")
        if reward.get("stale_generation") != 0 or reward.get("stale_accepted") is not False:
            errors.append(f"{prefix} must reject stale generation zero")
        if reward.get("stale_rejection_reason") != "stale_generation":
            errors.append(f"{prefix}.stale_rejection_reason must be stale_generation")
        if reward.get("retry_reward_id") != reward_id or reward.get("stale_reward_id") != reward_id:
            errors.append(f"{prefix} retry/stale mappings must use the activity reward")
        if reward.get("retry_reward_store_id") != REQUIRED_REWARD_STORE or reward.get("stale_reward_store_id") != REQUIRED_REWARD_STORE:
            errors.append(f"{prefix} retry/stale mappings must use the canonical reward store")
        if reward.get("retry_committed_once") is not True or reward.get("stale_committed_once") is not True:
            errors.append(f"{prefix} retry/stale mappings must be committed exactly once")
    if tuple(activity_ids) != REQUIRED_ACTIVITY_IDS:
        errors.append(f"{label}.rewards must retain authored activity order")
    _unique(reward_ids, f"{label}.reward_ids", errors)
    _unique(guard_ids, f"{label}.guard_ids", errors)
    if len(guard_ids) == 10 and value.get("guard_id_count") != len(guard_ids):
        errors.append(f"{label}.guard_id_count must match authored guard IDs")

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
        print(f"PLANETARY_REWARD_KEYED_GUARDS_INVALID: {exc}")
        return 1
    errors = validate_catalog(report)
    if errors:
        print("PLANETARY_REWARD_KEYED_GUARDS_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PLANETARY_REWARD_KEYED_GUARDS_VALID: detached keyed guard uniqueness only")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
