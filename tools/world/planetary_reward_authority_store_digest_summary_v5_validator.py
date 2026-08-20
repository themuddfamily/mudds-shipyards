#!/usr/bin/env python3
"""Validate version-five planetary reward authority/store digest summary.

The v5 record binds five authored reward evidence leaves to the existing
GameFlow reward authority and store.  It is a detached digest artifact: no
store is created, no inventory is written, and no runtime/native path runs.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 5
EVIDENCE_SCOPE = "planetary_reward_authority_store_digest_summary_v5"
EVIDENCE_MODE = "detached_reward_authority_store_digest_v5"
REQUIRED_WORLD_ID = "ember_moon"
REQUIRED_REWARD_AUTHORITY = "game_flow_reward_authority"
REQUIRED_REWARD_STORE = "game_flow_reward_store"
REQUIRED_SOURCE = "detached_evidence"
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
    """Return blocking errors for one v5 authority/store digest summary."""

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
    if not _text(value.get("source_revision")):
        errors.append(f"{label}.source_revision is required")
    digest = value.get("digest_sha256")
    if not isinstance(digest, str) or len(digest) != 64 or any(character not in "0123456789abcdef" for character in digest):
        errors.append(f"{label}.digest_sha256 must be a lowercase SHA-256 hex digest")

    join = value.get("authority_store_join")
    if not isinstance(join, dict):
        errors.append(f"{label}.authority_store_join must be an object")
    else:
        for key, expected in (("reward_authority_id", REQUIRED_REWARD_AUTHORITY), ("reward_store_id", REQUIRED_REWARD_STORE), ("source", REQUIRED_SOURCE)):
            if join.get(key) != expected:
                errors.append(f"{label}.authority_store_join.{key} must be {expected}")
        for key in ("store_created_here", "inventory_writer_here", "runtime_wired", "native_run"):
            if join.get(key) is not False:
                errors.append(f"{label}.authority_store_join.{key} must be false")
        if join.get("committed_once") is not True:
            errors.append(f"{label}.authority_store_join.committed_once must be true")

    records = value.get("records")
    if not isinstance(records, list) or len(records) != len(REQUIRED_ACTIVITY_IDS):
        errors.append(f"{label}.records must contain exactly five authored records")
        records = []
    activity_ids: list[Any] = []
    reward_ids: list[Any] = []
    evidence_refs: list[Any] = []
    leaf_ids: list[Any] = []
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
        if record.get("reward_authority_id") != REQUIRED_REWARD_AUTHORITY or record.get("reward_store_id") != REQUIRED_REWARD_STORE:
            errors.append(f"{prefix} must use the existing reward authority and store")
        reward_id = record.get("reward_id")
        reward_ids.append(reward_id)
        if not _stable(reward_id):
            errors.append(f"{prefix}.reward_id must be stable lowercase text")
        leaf_id = record.get("digest_leaf_id")
        leaf_ids.append(leaf_id)
        if leaf_id != f"{activity_id}_authority_store_leaf":
            errors.append(f"{prefix}.digest_leaf_id must be deterministic")
        if not _stable(leaf_id):
            errors.append(f"{prefix}.digest_leaf_id must be stable lowercase text")
        evidence_ref = record.get("evidence_ref")
        evidence_refs.append(evidence_ref)
        if not _text(evidence_ref) or not evidence_ref.startswith("res://"):
            errors.append(f"{prefix}.evidence_ref must be a res:// path")
        if record.get("status") != "PASS" or record.get("included_once") is not True:
            errors.append(f"{prefix} must be PASS and included exactly once")
    if tuple(activity_ids) != REQUIRED_ACTIVITY_IDS:
        errors.append(f"{label}.records must retain authored activity order")
    _unique(reward_ids, f"{label}.reward_ids", errors)
    _unique(leaf_ids, f"{label}.digest_leaf_ids", errors)
    _unique(evidence_refs, f"{label}.evidence_refs", errors)

    counts = value.get("counts")
    if not isinstance(counts, dict):
        errors.append(f"{label}.counts must be an object")
    else:
        expected_counts = {"records": len(records), "digest_leaves": len(leaf_ids), "pass_records": sum(record.get("status") == "PASS" for record in records if isinstance(record, dict)), "store_creations": 0, "inventory_writes": 0, "runtime_mutations": 0, "native_runs": 0}
        for key, expected in expected_counts.items():
            if counts.get(key) != expected:
                errors.append(f"{label}.counts.{key} must be {expected}")
    if value.get("overall_status") != "PASS":
        errors.append(f"{label}.overall_status must be PASS")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("summary", type=Path)
    args = parser.parse_args(argv)
    try:
        report = json.loads(args.summary.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        print(f"PLANETARY_REWARD_AUTHORITY_STORE_V5_INVALID: {exc}")
        return 1
    errors = validate_summary(report)
    if errors:
        print("PLANETARY_REWARD_AUTHORITY_STORE_V5_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PLANETARY_REWARD_AUTHORITY_STORE_V5_VALID: detached authority/store summary only")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
