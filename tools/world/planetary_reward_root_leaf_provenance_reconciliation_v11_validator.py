#!/usr/bin/env python3
"""Validate version-eleven reward root/leaf provenance reconciliation.

The v11 manifest reconciles one detached root to exactly five ordered reward
leaves, references, and provenance IDs.  It performs no store, inventory,
runtime, or native write and makes no historical/procedural claim.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 11
EVIDENCE_SCOPE = "planetary_reward_root_leaf_provenance_reconciliation_v11"
EVIDENCE_MODE = "detached_reward_root_leaf_reconciliation_v11"
REQUIRED_WORLD_ID = "ember_moon"
REQUIRED_REWARD_AUTHORITY = "game_flow_reward_authority"
REQUIRED_REWARD_STORE = "game_flow_reward_store"
REQUIRED_ROOT_ID = "planetary_reward_evidence_root_v11"
REQUIRED_PROVENANCE_ID = "planetary_reward_provenance_v11"
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


def validate_reconciliation(value: Any, label: str = "reconciliation") -> list[str]:
    """Return blocking errors for one v11 root/leaf reconciliation artifact."""

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

    root = value.get("root")
    if not isinstance(root, dict):
        errors.append(f"{label}.root must be an object")
        root = {}
    else:
        if root.get("id") != REQUIRED_ROOT_ID:
            errors.append(f"{label}.root.id must be {REQUIRED_ROOT_ID}")
        root_ref = root.get("evidence_ref")
        if not _text(root_ref) or not root_ref.startswith("res://"):
            errors.append(f"{label}.root.evidence_ref must be a res:// path")
        if root.get("provenance_id") != REQUIRED_PROVENANCE_ID:
            errors.append(f"{label}.root.provenance_id must be {REQUIRED_PROVENANCE_ID}")
        if root.get("expected_leaf_count") != len(REQUIRED_ACTIVITY_IDS):
            errors.append(f"{label}.root.expected_leaf_count must be five")
        if root.get("status") != "PASS" or root.get("committed_once") is not True:
            errors.append(f"{label}.root must be PASS and committed exactly once")

    authority = value.get("authority")
    if not isinstance(authority, dict):
        errors.append(f"{label}.authority must be an object")
    else:
        for key, expected in (("reward_authority_id", REQUIRED_REWARD_AUTHORITY), ("reward_store_id", REQUIRED_REWARD_STORE), ("source", "detached_evidence")):
            if authority.get(key) != expected:
                errors.append(f"{label}.authority.{key} must be {expected}")
        for key in ("writes_store", "writes_inventory", "writes_runtime", "runs_native"):
            if authority.get(key) is not False:
                errors.append(f"{label}.authority.{key} must be false")

    leaves = value.get("leaves")
    if not isinstance(leaves, list) or len(leaves) != len(REQUIRED_ACTIVITY_IDS):
        errors.append(f"{label}.leaves must contain exactly five authored leaves")
        leaves = []
    activity_ids: list[Any] = []
    leaf_ids: list[Any] = []
    leaf_refs: list[Any] = []
    provenance_ids: list[Any] = []
    reward_ids: list[Any] = []
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
        if leaf_id != f"{activity_id}_reward_reconciled_leaf_v11":
            errors.append(f"{prefix}.leaf_id must be deterministic")
        if not _stable(leaf_id):
            errors.append(f"{prefix}.leaf_id must be stable lowercase text")
        if leaf.get("parent_id") != root.get("id"):
            errors.append(f"{prefix}.parent_id must match the root")
        provenance_id = leaf.get("provenance_id")
        provenance_ids.append(provenance_id)
        if provenance_id != root.get("provenance_id"):
            errors.append(f"{prefix}.provenance_id must reconcile to the root")
        leaf_ref = leaf.get("evidence_ref")
        leaf_refs.append(leaf_ref)
        if not _text(leaf_ref) or not leaf_ref.startswith("res://"):
            errors.append(f"{prefix}.evidence_ref must be a res:// path")
        if leaf.get("status") != "PASS" or leaf.get("included_once") is not True:
            errors.append(f"{prefix} must be PASS and included exactly once")
    if tuple(activity_ids) != REQUIRED_ACTIVITY_IDS:
        errors.append(f"{label}.leaves must retain authored activity order")
    _unique(leaf_ids, f"{label}.leaf_ids", errors)
    _unique(leaf_refs, f"{label}.leaf_refs", errors)
    _unique(reward_ids, f"{label}.reward_ids", errors)
    if set(provenance_ids) != {REQUIRED_PROVENANCE_ID}:
        errors.append(f"{label}.provenance_ids must reconcile to one root provenance ID")
    root_refs = [root.get("evidence_ref")] + leaf_refs
    _unique(root_refs, f"{label}.evidence_refs", errors)
    manifest = value.get("reconciled_manifest")
    if not isinstance(manifest, dict):
        errors.append(f"{label}.reconciled_manifest must be an object")
    else:
        if manifest.get("root_id") != root.get("id") or manifest.get("provenance_id") != root.get("provenance_id"):
            errors.append(f"{label}.reconciled_manifest root/provenance must match root")
        if manifest.get("leaf_ids") != leaf_ids or manifest.get("evidence_refs") != leaf_refs:
            errors.append(f"{label}.reconciled_manifest must enumerate the authored leaves exactly")
        if manifest.get("reconciled_once") is not True:
            errors.append(f"{label}.reconciled_manifest.reconciled_once must be true")
    counts = value.get("counts")
    if not isinstance(counts, dict):
        errors.append(f"{label}.counts must be an object")
    else:
        expected_counts = {"leaves": len(leaves), "evidence_refs": len(root_refs), "reconciled_leaves": len(leaves), "pass_leaves": sum(leaf.get("status") == "PASS" for leaf in leaves if isinstance(leaf, dict)), "store_writes": 0, "inventory_writes": 0, "runtime_mutations": 0, "native_runs": 0}
        for key, expected in expected_counts.items():
            if counts.get(key) != expected:
                errors.append(f"{label}.counts.{key} must be {expected}")
    if value.get("overall_status") != "PASS":
        errors.append(f"{label}.overall_status must be PASS")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("reconciliation", type=Path)
    args = parser.parse_args(argv)
    try:
        report = json.loads(args.reconciliation.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        print(f"PLANETARY_REWARD_RECONCILIATION_V11_INVALID: {exc}")
        return 1
    errors = validate_reconciliation(report)
    if errors:
        print("PLANETARY_REWARD_RECONCILIATION_V11_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PLANETARY_REWARD_RECONCILIATION_V11_VALID: detached root/leaf reconciliation only")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
