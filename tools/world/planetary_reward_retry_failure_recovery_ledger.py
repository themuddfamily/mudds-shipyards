#!/usr/bin/env python3
"""Validate detached planetary reward retry/failure-recovery evidence.

The ledger proves that authored activities have a bounded failure edge, a
generation-fenced retry, and exactly-once reward semantics.  It does not
perform recovery, reset an activity, or write a reward inventory.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 1
EVIDENCE_SCOPE = "planetary_reward_retry_failure_recovery"
EVIDENCE_MODE = "detached_recovery_fixture"
REQUIRED_WORLD_ID = "ember_moon"
REQUIRED_ACTIVITY_IDS = (
    "ember_beacon_survey",
    "ember_caldera_patrol",
    "ember_kit_cargo_run",
    "ember_checkpoint_race",
    "ember_convoy_escort",
)
VALID_RECOVERY_IDS = {"return_to_landed_ship", "abort_to_orbit_return", "reset_at_start_beacon", "recover_convoy_at_return_beacon"}
VALID_FAILURE_STATES = {"failed", "aborted", "timed_out", "destroyed"}
VALID_RECOVERY_TARGETS = {"landed_ship", "orbit_return", "start_beacon", "convoy_return_beacon"}


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _positive_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value > 0


def validate_ledger(value: Any, label: str = "ledger") -> list[str]:
    """Return blocking errors for one detached failure/retry ledger."""

    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    if value.get("evidence_scope") != EVIDENCE_SCOPE:
        errors.append(f"{label}.evidence_scope must be {EVIDENCE_SCOPE}")
    if value.get("evidence_mode") != EVIDENCE_MODE:
        errors.append(f"{label}.evidence_mode must be {EVIDENCE_MODE}")
    for key in ("runtime_authority", "reward_inventory", "recovery_mutation", "native_claims"):
        if value.get(key) is not False:
            errors.append(f"{label}.{key} must be false")
    if value.get("world_id") != REQUIRED_WORLD_ID:
        errors.append(f"{label}.world_id must be {REQUIRED_WORLD_ID}")
    if not _text(value.get("source_revision")):
        errors.append(f"{label}.source_revision is required")

    activities = value.get("activities")
    if not isinstance(activities, list) or len(activities) != len(REQUIRED_ACTIVITY_IDS):
        errors.append(f"{label}.activities must contain exactly five authored activities")
        activities = []
    activity_ids: list[str] = []
    for index, activity in enumerate(activities):
        prefix = f"{label}.activities[{index}]"
        if not isinstance(activity, dict):
            errors.append(f"{prefix} must be an object")
            continue
        activity_id = activity.get("activity_id")
        activity_ids.append(activity_id)
        if activity_id != REQUIRED_ACTIVITY_IDS[index]:
            errors.append(f"{prefix}.activity_id must be {REQUIRED_ACTIVITY_IDS[index]}")
        if not _positive_int(activity.get("attempt_generation")):
            errors.append(f"{prefix}.attempt_generation must be positive")
        if activity.get("failure_state") not in VALID_FAILURE_STATES:
            errors.append(f"{prefix}.failure_state must be an authored failure state")
        if not _text(activity.get("failure_reason")):
            errors.append(f"{prefix}.failure_reason is required")
        if activity.get("recovery_id") not in VALID_RECOVERY_IDS:
            errors.append(f"{prefix}.recovery_id must be an existing recovery ID")
        if activity.get("recovery_target") not in VALID_RECOVERY_TARGETS:
            errors.append(f"{prefix}.recovery_target must be an authored recovery target")
        if not _text(activity.get("recovery_route_id")):
            errors.append(f"{prefix}.recovery_route_id is required")
        if activity.get("recovery_accepted") is not True:
            errors.append(f"{prefix}.recovery_accepted must be true")
        if activity.get("recovery_once") is not True:
            errors.append(f"{prefix}.recovery_once must be true")
        if activity.get("retry_allowed") is not True:
            errors.append(f"{prefix}.retry_allowed must be true")
        if activity.get("retry_generation") != activity.get("attempt_generation", 0) + 1:
            errors.append(f"{prefix}.retry_generation must advance exactly once")
        if activity.get("stale_recovery_accepted") is not False:
            errors.append(f"{prefix}.stale_recovery_accepted must be false")
        if activity.get("stale_rejection_reason") not in {"stale_generation", "recovery_generation_mismatch"}:
            errors.append(f"{prefix}.stale_rejection_reason must name a generation rejection")
        if activity.get("reward_granted_before_failure") is not False:
            errors.append(f"{prefix}.reward_granted_before_failure must be false")
        if activity.get("reward_grant_once") is not True:
            errors.append(f"{prefix}.reward_grant_once must be true")
        if activity.get("duplicate_reward_rejected") is not True:
            errors.append(f"{prefix}.duplicate_reward_rejected must be true")
    if tuple(activity_ids) != REQUIRED_ACTIVITY_IDS:
        errors.append(f"{label}.activities must retain authored activity order")

    authority = value.get("authority")
    if not isinstance(authority, dict):
        errors.append(f"{label}.authority must be an object")
    else:
        for key in ("activity", "objective", "reward", "reward_store", "recovery", "save", "network", "gameplay", "clock"):
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
        print(f"PLANETARY_REWARD_RECOVERY_INVALID: {exc}")
        return 1
    errors = validate_ledger(report)
    if errors:
        print("PLANETARY_REWARD_RECOVERY_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PLANETARY_REWARD_RECOVERY_VALID: detached retry ledger only")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
