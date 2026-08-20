#!/usr/bin/env python3
"""Validate version-nine planetary reward provenance lineage digest.

The v9 artifact records five deterministic reward evidence lineage leaves under
one detached root and hashes that canonical lineage/reference set.  It makes
no runtime, inventory, store, native, historical, or procedural claim.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 9
EVIDENCE_SCOPE = "planetary_reward_provenance_lineage_digest_v9"
EVIDENCE_MODE = "detached_reward_provenance_lineage_v9"
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
REQUIRED_ROOT_ID = "planetary_reward_evidence_root_v9"


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _stable(value: Any) -> bool:
    return _text(value) and value == value.lower() and " " not in value and "__" not in value


def _unique(values: list[Any], label: str, errors: list[str]) -> None:
    if len(set(values)) != len(values):
        errors.append(f"{label} must not contain duplicates")


def _lineage_digest(root_id: str, leaves: list[dict[str, Any]]) -> str:
    payload = {
        "root_id": root_id,
        "leaves": [
            {"activity_id": leaf.get("activity_id"), "lineage_id": leaf.get("lineage_id"), "parent_id": leaf.get("parent_id"), "evidence_ref": leaf.get("evidence_ref"), "reward_id": leaf.get("reward_id")}
            for leaf in leaves
        ],
    }
    encoded = json.dumps(payload, ensure_ascii=True, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()


def validate_lineage(value: Any, label: str = "lineage") -> list[str]:
    """Return blocking errors for one v9 reward provenance lineage digest."""

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
    root_id = value.get("root_id")
    if root_id != REQUIRED_ROOT_ID:
        errors.append(f"{label}.root_id must be {REQUIRED_ROOT_ID}")
    provenance = value.get("provenance")
    if not isinstance(provenance, dict):
        errors.append(f"{label}.provenance must be an object")
        provenance = {}
    else:
        for key, expected in (("source", "detached_evidence"), ("lineage_version", "v9"), ("generated_by", "authored_fixture")):
            if provenance.get(key) != expected:
                errors.append(f"{label}.provenance.{key} must be {expected}")
        for key in ("runtime_generated", "historical_claim", "procedural_generation"):
            if provenance.get(key) is not False:
                errors.append(f"{label}.provenance.{key} must be false")
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
    lineage_ids: list[Any] = []
    references: list[Any] = []
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
        lineage_id = leaf.get("lineage_id")
        lineage_ids.append(lineage_id)
        if lineage_id != f"{activity_id}_reward_lineage_v9":
            errors.append(f"{prefix}.lineage_id must be deterministic")
        if not _stable(lineage_id):
            errors.append(f"{prefix}.lineage_id must be stable lowercase text")
        if leaf.get("parent_id") != root_id:
            errors.append(f"{prefix}.parent_id must reference the lineage root")
        reference = leaf.get("evidence_ref")
        references.append(reference)
        if not _text(reference) or not reference.startswith("res://"):
            errors.append(f"{prefix}.evidence_ref must be a res:// path")
        if leaf.get("status") != "PASS" or leaf.get("included_once") is not True:
            errors.append(f"{prefix} must be PASS and included exactly once")
    if tuple(activity_ids) != REQUIRED_ACTIVITY_IDS:
        errors.append(f"{label}.leaves must retain authored activity order")
    _unique(lineage_ids, f"{label}.lineage_ids", errors)
    _unique(references, f"{label}.evidence_refs", errors)
    _unique(reward_ids, f"{label}.reward_ids", errors)
    digest = value.get("lineage_digest_sha256")
    if not isinstance(digest, str) or len(digest) != 64 or any(character not in "0123456789abcdef" for character in digest):
        errors.append(f"{label}.lineage_digest_sha256 must be a lowercase SHA-256 hex digest")
    elif leaves and digest != _lineage_digest(root_id, leaves):
        errors.append(f"{label}.lineage_digest_sha256 does not match canonical lineage")
    counts = value.get("counts")
    if not isinstance(counts, dict):
        errors.append(f"{label}.counts must be an object")
    else:
        expected_counts = {"leaves": len(leaves), "unique_lineages": len(set(lineage_ids)), "unique_references": len(set(references)), "pass_leaves": sum(leaf.get("status") == "PASS" for leaf in leaves if isinstance(leaf, dict)), "store_writes": 0, "inventory_writes": 0, "runtime_mutations": 0, "native_runs": 0}
        for key, expected in expected_counts.items():
            if counts.get(key) != expected:
                errors.append(f"{label}.counts.{key} must be {expected}")
    if value.get("overall_status") != "PASS":
        errors.append(f"{label}.overall_status must be PASS")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("lineage", type=Path)
    args = parser.parse_args(argv)
    try:
        report = json.loads(args.lineage.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        print(f"PLANETARY_REWARD_LINEAGE_V9_INVALID: {exc}")
        return 1
    errors = validate_lineage(report)
    if errors:
        print("PLANETARY_REWARD_LINEAGE_V9_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PLANETARY_REWARD_LINEAGE_V9_VALID: detached provenance lineage only")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
