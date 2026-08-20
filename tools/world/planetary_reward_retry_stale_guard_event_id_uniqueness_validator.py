#!/usr/bin/env python3
"""Validate detached planetary reward retry/stale guard ID uniqueness.

The catalog contains exactly one retry and one stale guard ID per authored
activity.  It checks deterministic identity, ordering, and uniqueness without
granting rewards or owning runtime authority.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 1
EVIDENCE_SCOPE = "planetary_reward_retry_stale_guard_event_id_uniqueness"
EVIDENCE_MODE = "detached_reward_guard_id_catalog"
REQUIRED_WORLD_ID = "ember_moon"
REQUIRED_REWARD_STORE = "game_flow_reward_store"
REQUIRED_REWARD_AUTHORITY = "game_flow_reward_authority"
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
    ("retry", 2, True, False, "reward_retry_g2"),
    ("stale", 0, False, True, "reward_stale_g0"),
)
TOTAL_GUARDS = len(REQUIRED_ACTIVITY_IDS) * len(EXPECTED_GUARDS)


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _stable(value: Any) -> bool:
    return _text(value) and value == value.lower() and " " not in value and "__" not in value


def _unique(values: list[Any], label: str, errors: list[str]) -> None:
    if len(set(values)) != len(values):
        errors.append(f"{label} must not contain duplicates")


def validate_catalog(value: Any, label: str = "catalog") -> list[str]:
    """Return blocking errors for one detached guard-ID uniqueness catalog."""

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
    if value.get("guard_count") != TOTAL_GUARDS:
        errors.append(f"{label}.guard_count must be exactly ten")
    if not _text(value.get("source_revision")):
        errors.append(f"{label}.source_revision is required")

    guards = value.get("guards")
    if not isinstance(guards, list) or len(guards) != TOTAL_GUARDS:
        errors.append(f"{label}.guards must contain exactly ten ordered guards")
        guards = []
    guard_ids: list[Any] = []
    reward_ids: list[Any] = []
    observed_count = 0
    for index, guard in enumerate(guards):
        prefix = f"{label}.guards[{index}]"
        if not isinstance(guard, dict):
            errors.append(f"{prefix} must be an object")
            continue
        activity_index = index // len(EXPECTED_GUARDS)
        guard_index = index % len(EXPECTED_GUARDS)
        expected_activity = REQUIRED_ACTIVITY_IDS[activity_index]
        expected_kind, expected_generation, expected_accepted, expected_rejected, expected_suffix = EXPECTED_GUARDS[guard_index]
        activity_id = guard.get("activity_id")
        if activity_id != expected_activity:
            errors.append(f"{prefix}.activity_id must be {expected_activity}")
        if guard.get("kind") != expected_kind:
            errors.append(f"{prefix}.kind must be {expected_kind}")
        event_id = guard.get("event_id")
        guard_ids.append(event_id)
        observed_count += 1
        expected_event_id = f"{expected_activity}_{expected_suffix}"
        if event_id != expected_event_id:
            errors.append(f"{prefix}.event_id must be deterministic for the guard")
        if not _stable(event_id):
            errors.append(f"{prefix}.event_id must be stable lowercase text")
        if guard.get("generation") != expected_generation:
            errors.append(f"{prefix}.generation must be {expected_generation}")
        if guard.get("accepted") is not expected_accepted:
            errors.append(f"{prefix}.accepted has an invalid guard outcome")
        if guard.get("rejected") is not expected_rejected:
            errors.append(f"{prefix}.rejected has an invalid guard outcome")
        reward_id = guard.get("reward_id")
        reward_ids.append(reward_id)
        if not _stable(reward_id):
            errors.append(f"{prefix}.reward_id must be stable lowercase text")
        if guard.get("activity_authority_id") not in EXISTING_ACTIVITY_AUTHORITIES:
            errors.append(f"{prefix}.activity_authority_id must use an existing activity authority")
        if guard.get("reward_authority_id") != REQUIRED_REWARD_AUTHORITY:
            errors.append(f"{prefix}.reward_authority_id must be {REQUIRED_REWARD_AUTHORITY}")
        if guard.get("reward_store_id") != REQUIRED_REWARD_STORE:
            errors.append(f"{prefix}.reward_store_id must use the canonical reward store")
        if guard.get("committed_once") is not True:
            errors.append(f"{prefix}.committed_once must be true")
    _unique(guard_ids, f"{label}.guard_ids", errors)
    if observed_count != value.get("guard_count"):
        errors.append(f"{label}.guard_count must match authored guard records")
    if len(reward_ids) == TOTAL_GUARDS:
        for index in range(0, TOTAL_GUARDS, 2):
            if reward_ids[index] != reward_ids[index + 1]:
                errors.append(f"{label}.guards[{index}:{index + 2}] must share one activity reward ID")

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
        print(f"PLANETARY_REWARD_GUARD_UNIQUENESS_INVALID: {exc}")
        return 1
    errors = validate_catalog(report)
    if errors:
        print("PLANETARY_REWARD_GUARD_UNIQUENESS_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PLANETARY_REWARD_GUARD_UNIQUENESS_VALID: detached guard-ID uniqueness only")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
