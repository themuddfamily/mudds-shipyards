#!/usr/bin/env python3
"""Validate detached v30 planetary reward paired root/authority evidence."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 30
EVIDENCE_SCOPE = "planetary_reward_paired_root_authority_v30"
EVIDENCE_MODE = "detached_reward_paired_root_authority_v30"
REQUIRED_WORLD_ID = "ember_moon"
REQUIRED_MANIFEST_ID = "planetary_reward_manifest_v30"
REQUIRED_PROVENANCE_ID = "planetary_reward_provenance_v30"
REQUIRED_LINEAGE_ID = "planetary_reward_lineage_v30"
REQUIRED_LINEAGE_ROOT = "detached_reward_evidence_root_v30"
REQUIRED_REWARD_AUTHORITY = "game_flow_reward_authority"
REQUIRED_REWARD_STORE = "game_flow_reward_store"
REQUIRED_AUTHORITY_SCOPE = "planetary_reward_paired_root_authority"
REQUIRED_ACTIVITY_IDS = ("ember_beacon_survey", "ember_caldera_patrol", "ember_kit_cargo_run", "ember_checkpoint_race", "ember_convoy_escort")
EXISTING_ACTIVITY_AUTHORITIES = {"activity_director", "cargo_delivery_activity", "timed_checkpoint_race", "convoy_escort_activity"}


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _stable(value: Any) -> bool:
    return _text(value) and value == value.lower() and " " not in value and "__" not in value


def _unique(values: list[Any], label: str, errors: list[str]) -> None:
    try:
        duplicate = len(set(values)) != len(values)
    except TypeError:
        duplicate = len({repr(item) for item in values}) != len(values)
    if duplicate:
        errors.append(f"{label} must not contain duplicates")


def _digest(payload: Any) -> str:
    encoded = json.dumps(payload, ensure_ascii=True, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()


def _paired_root_authority_digests(identity: dict[str, Any], authority: dict[str, Any], root: dict[str, Any], reconciliation: dict[str, Any], records: list[dict[str, Any]]) -> tuple[str, str, str]:
    root_digest = _digest({"lineage_root": root, "identity": {key: identity.get(key) for key in ("manifest_id", "provenance_id", "manifest_version", "lineage_id", "evidence_ref")}})
    authority_digest = _digest({"authority": {key: authority.get(key) for key in ("reward_authority_id", "reward_store_id", "authority_scope")}, "records": [{key: record.get(key) for key in ("activity_id", "activity_authority_id", "reward_authority_id", "reward_store_id", "reward_id", "leaf_id", "evidence_ref", "status")} for record in records]})
    pair_digest = _digest({"lineage_root_digest_sha256": root_digest, "authority_digest_sha256": authority_digest, "reconciliation": reconciliation})
    return root_digest, authority_digest, pair_digest


def validate_paired_root_authority(value: Any, label: str = "manifest") -> list[str]:
    """Return blocking errors for one v30 paired root/authority artifact."""

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

    identity = value.get("identity")
    if not isinstance(identity, dict):
        errors.append(f"{label}.identity must be an object")
        identity = {}
    else:
        for key, expected in (("manifest_id", REQUIRED_MANIFEST_ID), ("provenance_id", REQUIRED_PROVENANCE_ID), ("manifest_version", "v30"), ("lineage_id", REQUIRED_LINEAGE_ID), ("source", "detached_evidence")):
            if identity.get(key) != expected:
                errors.append(f"{label}.identity.{key} must be {expected}")
        identity_ref = identity.get("evidence_ref")
        if not _text(identity_ref) or not identity_ref.startswith("res://"):
            errors.append(f"{label}.identity.evidence_ref must be a res:// path")
        for key in ("writes_store", "writes_inventory", "writes_runtime", "runs_native"):
            if identity.get(key) is not False:
                errors.append(f"{label}.identity.{key} must be false")

    authority = value.get("authority")
    if not isinstance(authority, dict):
        errors.append(f"{label}.authority must be an object")
        authority = {}
    else:
        for key, expected in (("reward_authority_id", REQUIRED_REWARD_AUTHORITY), ("reward_store_id", REQUIRED_REWARD_STORE), ("authority_scope", REQUIRED_AUTHORITY_SCOPE), ("source", "detached_evidence")):
            if authority.get(key) != expected:
                errors.append(f"{label}.authority.{key} must be {expected}")
        for key in ("writes_store", "writes_inventory", "writes_runtime", "runs_native"):
            if authority.get(key) is not False:
                errors.append(f"{label}.authority.{key} must be false")

    records = value.get("records")
    if not isinstance(records, list) or len(records) != 5:
        errors.append(f"{label}.records must contain exactly five authored records")
        records = []
    activity_ids: list[Any] = []
    reward_ids: list[Any] = []
    leaf_ids: list[Any] = []
    refs: list[Any] = []
    for index, record in enumerate(records):
        prefix = f"{label}.records[{index}]"
        if not isinstance(record, dict):
            errors.append(f"{prefix} must be an object")
            continue
        activity_id = record.get("activity_id")
        activity_ids.append(activity_id)
        if activity_id != REQUIRED_ACTIVITY_IDS[index]:
            errors.append(f"{prefix}.activity_id must be {REQUIRED_ACTIVITY_IDS[index]}")
        if record.get("manifest_id") != identity.get("manifest_id") or record.get("provenance_id") != identity.get("provenance_id"):
            errors.append(f"{prefix} manifest/provenance IDs must match identity")
        if record.get("activity_authority_id") not in EXISTING_ACTIVITY_AUTHORITIES:
            errors.append(f"{prefix}.activity_authority_id must use an existing activity authority")
        if record.get("reward_authority_id") != REQUIRED_REWARD_AUTHORITY or record.get("reward_store_id") != REQUIRED_REWARD_STORE:
            errors.append(f"{prefix} must reconcile to the paired root authority and store")
        reward_id = record.get("reward_id")
        reward_ids.append(reward_id)
        if not _stable(reward_id):
            errors.append(f"{prefix}.reward_id must be stable lowercase text")
        leaf_id = record.get("leaf_id")
        leaf_ids.append(leaf_id)
        if leaf_id != f"{activity_id}_reward_root_authority_leaf_v30":
            errors.append(f"{prefix}.leaf_id must be deterministic")
        if not _stable(leaf_id):
            errors.append(f"{prefix}.leaf_id must be stable lowercase text")
        reference = record.get("evidence_ref")
        refs.append(reference)
        if not _text(reference) or not reference.startswith("res://"):
            errors.append(f"{prefix}.evidence_ref must be a res:// path")
        if record.get("status") != "PASS" or record.get("included_once") is not True:
            errors.append(f"{prefix} must be PASS and included exactly once")
    if tuple(activity_ids) != REQUIRED_ACTIVITY_IDS:
        errors.append(f"{label}.records must retain authored activity order")
    _unique(reward_ids, f"{label}.reward_ids", errors)
    _unique(leaf_ids, f"{label}.leaf_ids", errors)
    _unique(refs, f"{label}.evidence_refs", errors)
    identity_ref = identity.get("evidence_ref")
    all_refs = [identity_ref] + refs
    _unique(all_refs, f"{label}.all_evidence_refs", errors)

    root = value.get("lineage_root")
    if not isinstance(root, dict):
        errors.append(f"{label}.lineage_root must be an object")
        root = {}
    else:
        for key, expected in (("lineage_id", REQUIRED_LINEAGE_ID), ("root_id", REQUIRED_LINEAGE_ROOT), ("source", "detached_evidence")):
            if root.get(key) != expected:
                errors.append(f"{label}.lineage_root.{key} must be {expected}")
        root_ref = root.get("evidence_ref")
        if not _text(root_ref) or not root_ref.startswith("res://"):
            errors.append(f"{label}.lineage_root.evidence_ref must be a res:// path")
        if root_ref in all_refs:
            errors.append(f"{label}.lineage_root.evidence_ref must be unique")

    reconciliation = value.get("paired_root_authority_reconciliation")
    if not isinstance(reconciliation, dict):
        errors.append(f"{label}.paired_root_authority_reconciliation must be an object")
        reconciliation = {}
    else:
        reconciled = sum(record.get("manifest_id") == REQUIRED_MANIFEST_ID and record.get("provenance_id") == REQUIRED_PROVENANCE_ID and record.get("reward_authority_id") == REQUIRED_REWARD_AUTHORITY and record.get("reward_store_id") == REQUIRED_REWARD_STORE for record in records if isinstance(record, dict))
        expected = {"algorithm": "sha256", "canonicalization": "json_sort_keys_compact", "manifest_id": REQUIRED_MANIFEST_ID, "provenance_id": REQUIRED_PROVENANCE_ID, "lineage_id": REQUIRED_LINEAGE_ID, "root_id": REQUIRED_LINEAGE_ROOT, "reward_authority_id": REQUIRED_REWARD_AUTHORITY, "reward_store_id": REQUIRED_REWARD_STORE, "records_expected": 5, "records_observed": len(records), "references_expected": 6, "references_observed": len(all_refs), "records_reconciled": reconciled, "root_reconciled": root.get("root_id") == REQUIRED_LINEAGE_ROOT, "authority_reconciled": authority.get("reward_authority_id") == REQUIRED_REWARD_AUTHORITY and authority.get("reward_store_id") == REQUIRED_REWARD_STORE, "all_fields_present": True, "all_status_pass": sum(record.get("status") == "PASS" for record in records if isinstance(record, dict)) == 5, "complete": True}
        for key, expected_value in expected.items():
            if reconciliation.get(key) != expected_value:
                errors.append(f"{label}.paired_root_authority_reconciliation.{key} must be {expected_value}")
        reconciliation_ref = reconciliation.get("evidence_ref")
        if not _text(reconciliation_ref) or not reconciliation_ref.startswith("res://"):
            errors.append(f"{label}.paired_root_authority_reconciliation.evidence_ref must be a res:// path")
        if reconciliation_ref in all_refs:
            errors.append(f"{label}.paired_root_authority_reconciliation.evidence_ref must be unique")

    expected_root, expected_authority, expected_pair = _paired_root_authority_digests(identity, authority, root, reconciliation, records)
    for key, expected_value in (("lineage_root_digest_sha256", expected_root), ("authority_digest_sha256", expected_authority), ("paired_root_authority_digest_sha256", expected_pair)):
        digest = value.get(key)
        if not isinstance(digest, str) or len(digest) != 64 or any(character not in "0123456789abcdef" for character in digest):
            errors.append(f"{label}.{key} must be a lowercase SHA-256 hex digest")
        elif records and digest != expected_value:
            errors.append(f"{label}.{key} does not match canonical root/authority digest payload")

    counts = value.get("counts")
    if not isinstance(counts, dict):
        errors.append(f"{label}.counts must be an object")
    else:
        reconciled = sum(record.get("manifest_id") == REQUIRED_MANIFEST_ID and record.get("provenance_id") == REQUIRED_PROVENANCE_ID and record.get("reward_authority_id") == REQUIRED_REWARD_AUTHORITY and record.get("reward_store_id") == REQUIRED_REWARD_STORE for record in records if isinstance(record, dict))
        expected_counts = {"records": len(records), "references": len(all_refs), "records_reconciled": reconciled, "complete_records": sum(record.get("status") == "PASS" for record in records if isinstance(record, dict)), "store_writes": 0, "inventory_writes": 0, "runtime_mutations": 0, "native_runs": 0}
        for key, expected_value in expected_counts.items():
            if counts.get(key) != expected_value:
                errors.append(f"{label}.counts.{key} must be {expected_value}")
    if value.get("overall_status") != "PASS":
        errors.append(f"{label}.overall_status must be PASS")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    args = parser.parse_args(argv)
    try:
        report = json.loads(args.manifest.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        print(f"PLANETARY_REWARD_ROOT_AUTHORITY_V30_INVALID: {exc}")
        return 1
    errors = validate_paired_root_authority(report)
    if errors:
        print("PLANETARY_REWARD_ROOT_AUTHORITY_V30_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PLANETARY_REWARD_ROOT_AUTHORITY_V30_VALID: detached paired root/authority only")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
