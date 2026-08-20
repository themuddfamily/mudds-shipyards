#!/usr/bin/env python3
"""Validate a detached keyed reward retry/stale event mapping ledger.

The ledger maps deterministic retry and stale event IDs to their reward key,
generation fence, and outcome.  It contains no inventory mutation or runtime
reward authority.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 1
EVIDENCE_SCOPE = "planetary_keyed_reward_retry_stale_event_mapping"
EVIDENCE_MODE = "detached_keyed_reward_event_ledger"
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
EXPECTED_EVENTS = (
    ("reward_retry", 2, 1, 2, True, False, "reward_retry_g2"),
    ("reward_stale", 0, 0, 2, False, True, "reward_stale_g0"),
)


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _stable(value: Any) -> bool:
    return _text(value) and value == value.lower() and " " not in value and "__" not in value


def _unique(values: list[Any], label: str, errors: list[str]) -> None:
    if len(set(values)) != len(values):
        errors.append(f"{label} must not contain duplicates")


def validate_ledger(value: Any, label: str = "ledger") -> list[str]:
    """Return blocking errors for one detached keyed reward event ledger."""

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
    if value.get("event_count") != 10:
        errors.append(f"{label}.event_count must be exactly ten")
    if not _text(value.get("source_revision")):
        errors.append(f"{label}.source_revision is required")

    events = value.get("events")
    if not isinstance(events, list) or len(events) != 10:
        errors.append(f"{label}.events must contain exactly ten ordered mappings")
        events = []
    event_ids: list[Any] = []
    reward_ids: list[Any] = []
    observed_count = 0
    for index, event in enumerate(events):
        prefix = f"{label}.events[{index}]"
        if not isinstance(event, dict):
            errors.append(f"{prefix} must be an object")
            continue
        activity_index = index // 2
        event_index = index % 2
        expected_activity = REQUIRED_ACTIVITY_IDS[activity_index]
        expected_type, expected_submitted, expected_source, expected_current, expected_accepted, expected_rejected, suffix = EXPECTED_EVENTS[event_index]
        if event.get("activity_id") != expected_activity:
            errors.append(f"{prefix}.activity_id must be {expected_activity}")
        if event.get("event_type") != expected_type:
            errors.append(f"{prefix}.event_type must be {expected_type}")
        event_id = event.get("event_id")
        event_ids.append(event_id)
        observed_count += 1
        expected_event_id = f"{expected_activity}_{suffix}"
        if event_id != expected_event_id:
            errors.append(f"{prefix}.event_id must be deterministic for the mapping")
        if not _stable(event_id):
            errors.append(f"{prefix}.event_id must be stable lowercase text")
        if event.get("submitted_generation") != expected_submitted:
            errors.append(f"{prefix}.submitted_generation must be {expected_submitted}")
        if event.get("source_generation") != expected_source or event.get("current_generation") != expected_current:
            errors.append(f"{prefix} source/current generations must match the authored fence")
        if event.get("accepted") is not expected_accepted:
            errors.append(f"{prefix}.accepted has an invalid event outcome")
        if event.get("rejected") is not expected_rejected:
            errors.append(f"{prefix}.rejected has an invalid event outcome")
        if expected_type == "reward_stale" and event.get("reason") != "stale_generation":
            errors.append(f"{prefix}.reason must be stale_generation")
        if expected_type == "reward_retry" and event.get("reason") != "retry_generation":
            errors.append(f"{prefix}.reason must be retry_generation")
        reward_id = event.get("reward_id")
        reward_ids.append(reward_id)
        if not _stable(reward_id):
            errors.append(f"{prefix}.reward_id must be stable lowercase text")
        if event.get("activity_authority_id") not in EXISTING_ACTIVITY_AUTHORITIES:
            errors.append(f"{prefix}.activity_authority_id must use an existing activity authority")
        if event.get("reward_authority_id") != REQUIRED_REWARD_AUTHORITY:
            errors.append(f"{prefix}.reward_authority_id must be {REQUIRED_REWARD_AUTHORITY}")
        if event.get("reward_store_id") != REQUIRED_REWARD_STORE:
            errors.append(f"{prefix}.reward_store_id must use the canonical reward store")
        if event.get("committed_once") is not True:
            errors.append(f"{prefix}.committed_once must be true")
    _unique(event_ids, f"{label}.event_ids", errors)
    if observed_count != value.get("event_count"):
        errors.append(f"{label}.event_count must match authored event mappings")
    if len(reward_ids) == 10:
        for index in range(0, 10, 2):
            if reward_ids[index] != reward_ids[index + 1]:
                errors.append(f"{label}.events[{index}:{index + 2}] must share one reward ID")
    if tuple(event.get("activity_id") for event in events if isinstance(event, dict)) != tuple(
        activity_id for activity_id in REQUIRED_ACTIVITY_IDS for _ in EXPECTED_EVENTS
    ):
        errors.append(f"{label}.events must retain authored activity/event order")

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
    parser.add_argument("ledger", type=Path)
    args = parser.parse_args(argv)
    try:
        report = json.loads(args.ledger.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        print(f"PLANETARY_KEYED_REWARD_EVENTS_INVALID: {exc}")
        return 1
    errors = validate_ledger(report)
    if errors:
        print("PLANETARY_KEYED_REWARD_EVENTS_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PLANETARY_KEYED_REWARD_EVENTS_VALID: detached keyed event mapping only")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
