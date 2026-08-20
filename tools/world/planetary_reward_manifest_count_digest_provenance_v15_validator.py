#!/usr/bin/env python3
"""Validate version-fifteen reward manifest count/digest provenance.

The v15 artifact hashes a canonical manifest/provenance/count payload over five
reward records.  It is detached evidence and performs no store, inventory,
runtime, or native write.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 15
EVIDENCE_SCOPE = "planetary_reward_manifest_count_digest_provenance_v15"
EVIDENCE_MODE = "detached_reward_manifest_count_digest_v15"
REQUIRED_WORLD_ID = "ember_moon"
REQUIRED_MANIFEST_ID = "planetary_reward_manifest_v15"
REQUIRED_PROVENANCE_ID = "planetary_reward_provenance_v15"
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


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _stable(value: Any) -> bool:
    return _text(value) and value == value.lower() and " " not in value and "__" not in value


def _unique(values: list[Any], label: str, errors: list[str]) -> None:
    if len(set(values)) != len(values):
        errors.append(f"{label} must not contain duplicates")


def _manifest_digest(manifest_id: str, provenance_id: str, counts: dict[str, Any], records: list[dict[str, Any]]) -> str:
    payload = {"manifest_id": manifest_id, "provenance_id": provenance_id, "counts": counts, "records": [{"activity_id": record.get("activity_id"), "leaf_id": record.get("leaf_id"), "evidence_ref": record.get("evidence_ref"), "reward_id": record.get("reward_id")} for record in records]}
    encoded = json.dumps(payload, ensure_ascii=True, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()


def validate_manifest(value: Any, label: str = "manifest") -> list[str]:
    """Return blocking errors for one v15 count/digest provenance artifact."""

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
        for key, expected in (("manifest_id", REQUIRED_MANIFEST_ID), ("provenance_id", REQUIRED_PROVENANCE_ID), ("source", "detached_evidence"), ("manifest_version", "v15")):
            if identity.get(key) != expected:
                errors.append(f"{label}.identity.{key} must be {expected}")
        if not _text(identity.get("evidence_ref")) or not identity["evidence_ref"].startswith("res://"):
            errors.append(f"{label}.identity.evidence_ref must be a res:// path")
        for key in ("writes_store", "writes_inventory", "writes_runtime", "runs_native"):
            if identity.get(key) is not False:
                errors.append(f"{label}.identity.{key} must be false")

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

    records = value.get("records")
    if not isinstance(records, list) or len(records) != len(REQUIRED_ACTIVITY_IDS):
        errors.append(f"{label}.records must contain exactly five authored records")
        records = []
    activity_ids: list[Any] = []
    leaf_ids: list[Any] = []
    refs: list[Any] = []
    reward_ids: list[Any] = []
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
            errors.append(f"{prefix} must use the existing reward authority and store")
        reward_id = record.get("reward_id")
        reward_ids.append(reward_id)
        if not _stable(reward_id):
            errors.append(f"{prefix}.reward_id must be stable lowercase text")
        leaf_id = record.get("leaf_id")
        leaf_ids.append(leaf_id)
        if leaf_id != f"{activity_id}_reward_count_digest_leaf_v15":
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
    _unique(leaf_ids, f"{label}.leaf_ids", errors)
    _unique(refs, f"{label}.evidence_refs", errors)
    _unique(reward_ids, f"{label}.reward_ids", errors)
    identity_ref = identity.get("evidence_ref")
    _unique([identity_ref] + refs, f"{label}.all_evidence_refs", errors)
    counts = value.get("counts")
    if not isinstance(counts, dict):
        errors.append(f"{label}.counts must be an object")
        counts = {}
    else:
        expected_counts = {"records": len(records), "leaf_ids": len(set(leaf_ids)), "evidence_refs": len(set([identity_ref] + refs)), "pass_records": sum(record.get("status") == "PASS" for record in records if isinstance(record, dict)), "store_writes": 0, "inventory_writes": 0, "runtime_mutations": 0, "native_runs": 0}
        for key, expected in expected_counts.items():
            if counts.get(key) != expected:
                errors.append(f"{label}.counts.{key} must be {expected}")
    digest = value.get("manifest_digest_sha256")
    if not isinstance(digest, str) or len(digest) != 64 or any(character not in "0123456789abcdef" for character in digest):
        errors.append(f"{label}.manifest_digest_sha256 must be a lowercase SHA-256 hex digest")
    elif records and digest != _manifest_digest(identity.get("manifest_id"), identity.get("provenance_id"), counts, records):
        errors.append(f"{label}.manifest_digest_sha256 does not match canonical manifest payload")
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
        print(f"PLANETARY_REWARD_MANIFEST_V15_INVALID: {exc}")
        return 1
    errors = validate_manifest(report)
    if errors:
        print("PLANETARY_REWARD_MANIFEST_V15_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PLANETARY_REWARD_MANIFEST_V15_VALID: detached count/digest provenance only")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
