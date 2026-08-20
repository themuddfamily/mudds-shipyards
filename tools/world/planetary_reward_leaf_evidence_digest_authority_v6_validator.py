#!/usr/bin/env python3
"""Validate version-six planetary reward leaf/evidence digest authority.

The v6 artifact contains five authored reward digest leaves and evidence
references owned by the existing GameFlow authority/store.  It is detached
evidence: no store, inventory, runtime, or native write is permitted.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 6
EVIDENCE_SCOPE = "planetary_reward_leaf_evidence_digest_authority_v6"
EVIDENCE_MODE = "detached_reward_leaf_digest_authority_v6"
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


def validate_authority(value: Any, label: str = "digest") -> list[str]:
    """Return blocking errors for one v6 reward leaf digest authority artifact."""

    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    if value.get("evidence_scope") != EVIDENCE_SCOPE:
        errors.append(f"{label}.evidence_scope must be {EVIDENCE_SCOPE}")
    if value.get("evidence_mode") != EVIDENCE_MODE:
        errors.append(f"{label}.evidence_mode must be {EVIDENCE_MODE}")
    for key in ("runtime_authority", "reward_inventory", "reward_runtime", "native_claims", "store_created", "historical_claim", "procedural_generation"):
        if value.get(key) is not False:
            errors.append(f"{label}.{key} must be false")
    if value.get("world_id") != REQUIRED_WORLD_ID:
        errors.append(f"{label}.world_id must be {REQUIRED_WORLD_ID}")
    if not _text(value.get("source_revision")):
        errors.append(f"{label}.source_revision is required")
    summary_digest = value.get("summary_digest_sha256")
    if not isinstance(summary_digest, str) or len(summary_digest) != 64 or any(character not in "0123456789abcdef" for character in summary_digest):
        errors.append(f"{label}.summary_digest_sha256 must be a lowercase SHA-256 hex digest")

    owner = value.get("leaf_authority")
    if not isinstance(owner, dict):
        errors.append(f"{label}.leaf_authority must be an object")
    else:
        for key, expected in (("owner_id", REQUIRED_REWARD_AUTHORITY), ("store_id", REQUIRED_REWARD_STORE), ("source", REQUIRED_SOURCE), ("contract_revision", "reward_leaf_digest_authority_v6")):
            if owner.get(key) != expected:
                errors.append(f"{label}.leaf_authority.{key} must be {expected}")
        for key in ("writes_store", "writes_inventory", "writes_runtime", "runs_native"):
            if owner.get(key) is not False:
                errors.append(f"{label}.leaf_authority.{key} must be false")
        if owner.get("committed_once") is not True:
            errors.append(f"{label}.leaf_authority.committed_once must be true")

    leaves = value.get("leaves")
    if not isinstance(leaves, list) or len(leaves) != len(REQUIRED_ACTIVITY_IDS):
        errors.append(f"{label}.leaves must contain exactly five authored leaves")
        leaves = []
    activity_ids: list[Any] = []
    leaf_ids: list[Any] = []
    reward_ids: list[Any] = []
    evidence_refs: list[Any] = []
    leaf_digests: list[Any] = []
    for index, leaf in enumerate(leaves):
        prefix = f"{label}.leaves[{index}]"
        if not isinstance(leaf, dict):
            errors.append(f"{prefix} must be an object")
            continue
        activity_id = leaf.get("activity_id")
        activity_ids.append(activity_id)
        if activity_id != REQUIRED_ACTIVITY_IDS[index]:
            errors.append(f"{prefix}.activity_id must be {REQUIRED_ACTIVITY_IDS[index]}")
        if leaf.get("activity_authority_id") not in EXISTING_ACTIVITY_AUTHORITIES:
            errors.append(f"{prefix}.activity_authority_id must use an existing activity authority")
        if leaf.get("reward_authority_id") != REQUIRED_REWARD_AUTHORITY or leaf.get("reward_store_id") != REQUIRED_REWARD_STORE:
            errors.append(f"{prefix} must use the existing reward authority and store")
        reward_id = leaf.get("reward_id")
        reward_ids.append(reward_id)
        if not _stable(reward_id):
            errors.append(f"{prefix}.reward_id must be stable lowercase text")
        leaf_id = leaf.get("leaf_id")
        leaf_ids.append(leaf_id)
        if leaf_id != f"{activity_id}_reward_leaf_v6":
            errors.append(f"{prefix}.leaf_id must be deterministic")
        if not _stable(leaf_id):
            errors.append(f"{prefix}.leaf_id must be stable lowercase text")
        leaf_digest = leaf.get("leaf_digest_sha256")
        leaf_digests.append(leaf_digest)
        if not isinstance(leaf_digest, str) or len(leaf_digest) != 64 or any(character not in "0123456789abcdef" for character in leaf_digest):
            errors.append(f"{prefix}.leaf_digest_sha256 must be a lowercase SHA-256 hex digest")
        evidence_ref = leaf.get("evidence_ref")
        evidence_refs.append(evidence_ref)
        if not _text(evidence_ref) or not evidence_ref.startswith("res://"):
            errors.append(f"{prefix}.evidence_ref must be a res:// path")
        if leaf.get("status") != "PASS" or leaf.get("included_once") is not True:
            errors.append(f"{prefix} must be PASS and included exactly once")
    if tuple(activity_ids) != REQUIRED_ACTIVITY_IDS:
        errors.append(f"{label}.leaves must retain authored activity order")
    _unique(leaf_ids, f"{label}.leaf_ids", errors)
    _unique(reward_ids, f"{label}.reward_ids", errors)
    _unique(evidence_refs, f"{label}.evidence_refs", errors)
    _unique(leaf_digests, f"{label}.leaf_digests", errors)
    counts = value.get("counts")
    if not isinstance(counts, dict):
        errors.append(f"{label}.counts must be an object")
    else:
        expected_counts = {"leaves": len(leaves), "evidence_refs": len(evidence_refs), "pass_leaves": sum(leaf.get("status") == "PASS" for leaf in leaves if isinstance(leaf, dict)), "store_writes": 0, "inventory_writes": 0, "runtime_mutations": 0, "native_runs": 0}
        for key, expected in expected_counts.items():
            if counts.get(key) != expected:
                errors.append(f"{label}.counts.{key} must be {expected}")
    if value.get("overall_status") != "PASS":
        errors.append(f"{label}.overall_status must be PASS")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("digest", type=Path)
    args = parser.parse_args(argv)
    try:
        report = json.loads(args.digest.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        print(f"PLANETARY_REWARD_LEAF_V6_INVALID: {exc}")
        return 1
    errors = validate_authority(report)
    if errors:
        print("PLANETARY_REWARD_LEAF_V6_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PLANETARY_REWARD_LEAF_V6_VALID: detached leaf/evidence authority only")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
