#!/usr/bin/env python3
"""Validate version-three reward digest authority and handoff summary.

Version three records detached handoff edges between objective evidence, the
existing GameFlow reward authority/store, and the landing-return contract.
Every edge is explicitly non-runtime and non-mutating.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 3
EVIDENCE_SCOPE = "planetary_reward_digest_authority_summary_v3"
EVIDENCE_MODE = "detached_reward_digest_authority_v3"
REQUIRED_WORLD_ID = "ember_moon"
REQUIRED_REWARD_AUTHORITY = "game_flow_reward_authority"
REQUIRED_REWARD_STORE = "game_flow_reward_store"
REQUIRED_RETURN_AUTHORITY = "planetary_landing_return_contract"
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
EXPECTED_HANDOFFS = (
    ("objective_evidence_to_reward", "objective_evidence", REQUIRED_REWARD_AUTHORITY),
    ("reward_to_store", REQUIRED_REWARD_AUTHORITY, REQUIRED_REWARD_STORE),
    ("reward_to_return", REQUIRED_REWARD_AUTHORITY, REQUIRED_RETURN_AUTHORITY),
)


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _stable(value: Any) -> bool:
    return _text(value) and value == value.lower() and " " not in value and "__" not in value


def _unique(values: list[Any], label: str, errors: list[str]) -> None:
    if len(set(values)) != len(values):
        errors.append(f"{label} must not contain duplicates")


def validate_summary(value: Any, label: str = "summary") -> list[str]:
    """Return blocking errors for one v3 detached authority summary."""

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

    owner = value.get("digest_authority")
    if not isinstance(owner, dict):
        errors.append(f"{label}.digest_authority must be an object")
    else:
        if owner.get("owner_id") != REQUIRED_REWARD_AUTHORITY:
            errors.append(f"{label}.digest_authority.owner_id must be {REQUIRED_REWARD_AUTHORITY}")
        if owner.get("store_id") != REQUIRED_REWARD_STORE:
            errors.append(f"{label}.digest_authority.store_id must be {REQUIRED_REWARD_STORE}")
        if owner.get("return_authority_id") != REQUIRED_RETURN_AUTHORITY:
            errors.append(f"{label}.digest_authority.return_authority_id must be {REQUIRED_RETURN_AUTHORITY}")
        if owner.get("source") != REQUIRED_SOURCE:
            errors.append(f"{label}.digest_authority.source must be {REQUIRED_SOURCE}")
        if owner.get("contract_revision") != "reward_digest_authority_v3":
            errors.append(f"{label}.digest_authority.contract_revision must be reward_digest_authority_v3")
        for key in ("owns_inventory", "writes_runtime", "runs_native"):
            if owner.get(key) is not False:
                errors.append(f"{label}.digest_authority.{key} must be false")

    handoffs = value.get("handoffs")
    if not isinstance(handoffs, list) or len(handoffs) != len(EXPECTED_HANDOFFS):
        errors.append(f"{label}.handoffs must contain exactly three authored handoffs")
        handoffs = []
    handoff_ids: list[Any] = []
    for index, handoff in enumerate(handoffs):
        prefix = f"{label}.handoffs[{index}]"
        if not isinstance(handoff, dict):
            errors.append(f"{prefix} must be an object")
            continue
        expected_id, expected_source, expected_target = EXPECTED_HANDOFFS[index]
        handoff_ids.append(handoff.get("id"))
        if handoff.get("id") != expected_id:
            errors.append(f"{prefix}.id must be {expected_id}")
        if handoff.get("source") != expected_source or handoff.get("target") != expected_target:
            errors.append(f"{prefix} source/target must match authored handoff")
        if handoff.get("runtime_wired") is not False or handoff.get("mutates_inventory") is not False or handoff.get("native_run") is not False:
            errors.append(f"{prefix} must remain detached and non-mutating")
        if handoff.get("committed_once") is not True:
            errors.append(f"{prefix}.committed_once must be true")
    _unique(handoff_ids, f"{label}.handoff_ids", errors)

    records = value.get("records")
    if not isinstance(records, list) or len(records) != len(REQUIRED_ACTIVITY_IDS):
        errors.append(f"{label}.records must contain exactly five authored records")
        records = []
    activity_ids: list[Any] = []
    reward_ids: list[Any] = []
    leaf_ids: list[Any] = []
    evidence_refs: list[Any] = []
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
        if leaf_id != f"{activity_id}_reward_digest_leaf":
            errors.append(f"{prefix}.digest_leaf_id must be deterministic")
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
        expected_counts = {"records": len(records), "handoffs": len(handoffs), "digest_leaves": len(leaf_ids), "pass_records": sum(record.get("status") == "PASS" for record in records if isinstance(record, dict)), "runtime_mutations": 0, "inventory_writes": 0, "native_runs": 0}
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
        print(f"PLANETARY_REWARD_DIGEST_V3_INVALID: {exc}")
        return 1
    errors = validate_summary(report)
    if errors:
        print("PLANETARY_REWARD_DIGEST_V3_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PLANETARY_REWARD_DIGEST_V3_VALID: detached handoff summary only")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
