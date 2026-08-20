#!/usr/bin/env python3
"""Validate a detached summary of planetary reward guard evidence.

The summary aggregates authored retry/stale guard records and their evidence
status.  Counts are checked against the records; no reward inventory or
runtime authority is exercised.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 1
EVIDENCE_SCOPE = "planetary_reward_guard_evidence_summary"
EVIDENCE_MODE = "detached_reward_guard_summary"
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


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _stable(value: Any) -> bool:
    return _text(value) and value == value.lower() and " " not in value and "__" not in value


def _unique(values: list[Any], label: str, errors: list[str]) -> None:
    if len(set(values)) != len(values):
        errors.append(f"{label} must not contain duplicates")


def validate_summary(value: Any, label: str = "summary") -> list[str]:
    """Return blocking errors for one detached reward guard summary."""

    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    if value.get("evidence_scope") != EVIDENCE_SCOPE:
        errors.append(f"{label}.evidence_scope must be {EVIDENCE_SCOPE}")
    if value.get("evidence_mode") != EVIDENCE_MODE:
        errors.append(f"{label}.evidence_mode must be {EVIDENCE_MODE}")
    for key in ("runtime_authority", "reward_inventory", "reward_runtime", "native_claims", "historical_claim", "procedural_generation"):
        if value.get(key) is not False:
            errors.append(f"{label}.{key} must be false")
    if value.get("world_id") != REQUIRED_WORLD_ID:
        errors.append(f"{label}.world_id must be {REQUIRED_WORLD_ID}")
    if value.get("reward_store_id") != REQUIRED_REWARD_STORE:
        errors.append(f"{label}.reward_store_id must use the one canonical reward store")
    if not _text(value.get("source_revision")):
        errors.append(f"{label}.source_revision is required")

    records = value.get("records")
    if not isinstance(records, list) or len(records) != len(REQUIRED_ACTIVITY_IDS):
        errors.append(f"{label}.records must contain exactly five authored guard records")
        records = []
    activity_ids: list[Any] = []
    reward_ids: list[Any] = []
    retry_ids: list[Any] = []
    stale_ids: list[Any] = []
    pass_count = 0
    retry_accepted_count = 0
    stale_rejected_count = 0
    for index, record in enumerate(records):
        prefix = f"{label}.records[{index}]"
        if not isinstance(record, dict):
            errors.append(f"{prefix} must be an object")
            continue
        activity_id = record.get("activity_id")
        activity_ids.append(activity_id)
        if activity_id != REQUIRED_ACTIVITY_IDS[index]:
            errors.append(f"{prefix}.activity_id must be {REQUIRED_ACTIVITY_IDS[index]}")
        if record.get("activity_authority_id") not in EXISTING_ACTIVITY_AUTHORITIES:
            errors.append(f"{prefix}.activity_authority_id must use an existing activity authority")
        if record.get("reward_authority_id") != REQUIRED_REWARD_AUTHORITY:
            errors.append(f"{prefix}.reward_authority_id must be {REQUIRED_REWARD_AUTHORITY}")
        reward_id = record.get("reward_id")
        reward_ids.append(reward_id)
        if not _stable(reward_id):
            errors.append(f"{prefix}.reward_id must be stable lowercase text")
        retry_id = record.get("retry_guard_id")
        stale_id = record.get("stale_guard_id")
        retry_ids.append(retry_id)
        stale_ids.append(stale_id)
        if retry_id != f"{activity_id}_reward_retry_g2":
            errors.append(f"{prefix}.retry_guard_id must be deterministic")
        if stale_id != f"{activity_id}_reward_stale_g0":
            errors.append(f"{prefix}.stale_guard_id must be deterministic")
        if not _stable(retry_id) or not _stable(stale_id):
            errors.append(f"{prefix} guard IDs must be stable lowercase text")
        if record.get("retry_generation") != 2 or record.get("retry_accepted") is not True:
            errors.append(f"{prefix} must record accepted retry generation two")
        if record.get("stale_generation") != 0 or record.get("stale_rejected") is not True:
            errors.append(f"{prefix} must record rejected stale generation zero")
        if record.get("status") != "PASS":
            errors.append(f"{prefix}.status must be PASS")
        if not _text(record.get("evidence_ref")) or not record["evidence_ref"].startswith("res://"):
            errors.append(f"{prefix}.evidence_ref must be a res:// path")
        if record.get("retry_accepted") is True:
            retry_accepted_count += 1
        if record.get("stale_rejected") is True:
            stale_rejected_count += 1
        if record.get("status") == "PASS":
            pass_count += 1
    if tuple(activity_ids) != REQUIRED_ACTIVITY_IDS:
        errors.append(f"{label}.records must retain authored activity order")
    _unique(reward_ids, f"{label}.reward_ids", errors)
    _unique(retry_ids, f"{label}.retry_guard_ids", errors)
    _unique(stale_ids, f"{label}.stale_guard_ids", errors)
    _unique(retry_ids + stale_ids, f"{label}.guard_ids", errors)

    summary = value.get("counts")
    if not isinstance(summary, dict):
        errors.append(f"{label}.counts must be an object")
    else:
        expected_counts = {
            "records": len(records),
            "retry_guards": len(retry_ids),
            "stale_guards": len(stale_ids),
            "retry_accepted": retry_accepted_count,
            "stale_rejected": stale_rejected_count,
            "pass_records": pass_count,
            "duplicate_guard_ids": 0,
            "runtime_mutations": 0,
            "native_runs": 0,
        }
        for key, expected in expected_counts.items():
            if summary.get(key) != expected:
                errors.append(f"{label}.counts.{key} must be {expected}")
    if value.get("overall_status") != "PASS":
        errors.append(f"{label}.overall_status must be PASS")

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
    parser.add_argument("summary", type=Path)
    args = parser.parse_args(argv)
    try:
        report = json.loads(args.summary.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        print(f"PLANETARY_REWARD_SUMMARY_INVALID: {exc}")
        return 1
    errors = validate_summary(report)
    if errors:
        print("PLANETARY_REWARD_SUMMARY_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PLANETARY_REWARD_SUMMARY_VALID: detached guard evidence summary only")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
