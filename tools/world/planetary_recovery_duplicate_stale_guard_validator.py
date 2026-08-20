#!/usr/bin/env python3
"""Validate detached planetary recovery duplicate/stale guard evidence.

The evidence captures fresh, duplicate, stale, and retry recovery submissions
for authored Ember activities.  It proves the expected generation fences and
rejection outcomes without accepting a request or mutating runtime state.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 1
EVIDENCE_SCOPE = "planetary_recovery_duplicate_stale_guards"
EVIDENCE_MODE = "detached_recovery_guard_fixture"
REQUIRED_WORLD_ID = "ember_moon"
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
EXISTING_RECOVERY_IDS = {
    "return_to_landed_ship",
    "abort_to_orbit_return",
    "reset_at_start_beacon",
    "recover_convoy_at_return_beacon",
}
EXPECTED_SUBMISSIONS = (
    ("fresh_recovery", 1, True, False, False),
    ("duplicate_recovery", 1, False, True, False),
    ("stale_recovery", 0, False, False, True),
    ("retry_recovery", 2, True, False, False),
)


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _stable(value: Any) -> bool:
    return _text(value) and value == value.lower() and " " not in value and "__" not in value


def _unique(values: list[Any], label: str, errors: list[str]) -> None:
    if len(set(values)) != len(values):
        errors.append(f"{label} must not contain duplicates")


def validate_guards(value: Any, label: str = "ledger") -> list[str]:
    """Return blocking errors for one detached recovery guard ledger."""

    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    if value.get("evidence_scope") != EVIDENCE_SCOPE:
        errors.append(f"{label}.evidence_scope must be {EVIDENCE_SCOPE}")
    if value.get("evidence_mode") != EVIDENCE_MODE:
        errors.append(f"{label}.evidence_mode must be {EVIDENCE_MODE}")
    for key in ("runtime_authority", "recovery_runtime", "objective_runtime", "movement_runtime", "native_claims"):
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
    activity_ids: list[Any] = []
    guard_event_ids: list[Any] = []
    for index, activity in enumerate(activities):
        prefix = f"{label}.activities[{index}]"
        if not isinstance(activity, dict):
            errors.append(f"{prefix} must be an object")
            continue
        activity_id = activity.get("activity_id")
        activity_ids.append(activity_id)
        if activity_id != REQUIRED_ACTIVITY_IDS[index]:
            errors.append(f"{prefix}.activity_id must be {REQUIRED_ACTIVITY_IDS[index]}")
        if activity.get("activity_authority_id") not in EXISTING_ACTIVITY_AUTHORITIES:
            errors.append(f"{prefix}.activity_authority_id must use an existing activity authority")
        if activity.get("recovery_authority_id") != "planetary_landing_return_contract":
            errors.append(f"{prefix}.recovery_authority_id must be planetary_landing_return_contract")
        if activity.get("recovery_id") not in EXISTING_RECOVERY_IDS:
            errors.append(f"{prefix}.recovery_id must use an existing recovery ID")
        if activity.get("attempt_generation") != 1 or activity.get("retry_generation") != 2:
            errors.append(f"{prefix} must fence retry generation from one to two")
        for key in ("recovery_accept_once", "duplicate_recovery_rejected", "stale_recovery_rejected", "retry_once"):
            if activity.get(key) is not True:
                errors.append(f"{prefix}.{key} must be true")

        submissions = activity.get("submissions")
        if not isinstance(submissions, list) or len(submissions) != len(EXPECTED_SUBMISSIONS):
            errors.append(f"{prefix}.submissions must contain exactly four ordered guard cases")
            submissions = []
        observed_kinds: list[Any] = []
        observed_event_ids: list[Any] = []
        for submission_index, submission in enumerate(submissions):
            submission_prefix = f"{prefix}.submissions[{submission_index}]"
            if not isinstance(submission, dict):
                errors.append(f"{submission_prefix} must be an object")
                continue
            expected_kind, expected_generation, expected_accepted, expected_duplicate, expected_stale = EXPECTED_SUBMISSIONS[submission_index]
            kind = submission.get("kind")
            event_id = submission.get("event_id")
            observed_kinds.append(kind)
            observed_event_ids.append(event_id)
            guard_event_ids.append(event_id)
            if kind != expected_kind:
                errors.append(f"{submission_prefix}.kind must be {expected_kind}")
            if submission.get("generation") != expected_generation:
                errors.append(f"{submission_prefix}.generation must be {expected_generation}")
            if submission.get("accepted") is not expected_accepted:
                errors.append(f"{submission_prefix}.accepted has an invalid guard outcome")
            if submission.get("duplicate_rejected") is not expected_duplicate:
                errors.append(f"{submission_prefix}.duplicate_rejected has an invalid guard outcome")
            if submission.get("stale_rejected") is not expected_stale:
                errors.append(f"{submission_prefix}.stale_rejected has an invalid guard outcome")
            if not _stable(event_id):
                errors.append(f"{submission_prefix}.event_id must be stable lowercase text")
            if submission.get("committed_once") is not True:
                errors.append(f"{submission_prefix}.committed_once must be true")
        _unique(observed_event_ids, f"{prefix}.submission_event_ids", errors)
        if tuple(observed_kinds) != tuple(item[0] for item in EXPECTED_SUBMISSIONS):
            errors.append(f"{prefix}.submissions must retain authored guard order")
    if tuple(activity_ids) != REQUIRED_ACTIVITY_IDS:
        errors.append(f"{label}.activities must retain authored activity order")
    _unique(guard_event_ids, f"{label}.guard_event_ids", errors)

    authority = value.get("authority")
    if not isinstance(authority, dict):
        errors.append(f"{label}.authority must be an object")
    else:
        for key in ("activity", "objective", "recovery", "movement", "save", "network", "gameplay"):
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
        print(f"PLANETARY_RECOVERY_GUARDS_INVALID: {exc}")
        return 1
    errors = validate_guards(report)
    if errors:
        print("PLANETARY_RECOVERY_GUARDS_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PLANETARY_RECOVERY_GUARDS_VALID: detached duplicate/stale evidence only")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
