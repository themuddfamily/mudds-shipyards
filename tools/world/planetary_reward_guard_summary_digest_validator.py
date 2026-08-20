#!/usr/bin/env python3
"""Validate a deterministic digest for planetary reward guard evidence.

The digest covers the authored retry/stale guard summary records in canonical
JSON order.  It is an integrity aid for detached evidence, not a runtime
authority, reward grant, or native execution claim.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 1
EVIDENCE_SCOPE = "planetary_reward_guard_summary_digest"
EVIDENCE_MODE = "detached_reward_guard_digest"
REQUIRED_WORLD_ID = "ember_moon"
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


def _digest_payload(records: list[dict[str, Any]]) -> str:
    payload = [
        {
            "activity_id": record.get("activity_id"),
            "retry_guard_id": record.get("retry_guard_id"),
            "stale_guard_id": record.get("stale_guard_id"),
            "reward_id": record.get("reward_id"),
            "status": record.get("status"),
        }
        for record in records
    ]
    encoded = json.dumps(payload, ensure_ascii=True, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()


def validate_digest(value: Any, label: str = "digest") -> list[str]:
    """Return blocking errors for one detached reward summary digest."""

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
    if value.get("record_count") != len(REQUIRED_ACTIVITY_IDS):
        errors.append(f"{label}.record_count must be exactly five")
    if not _text(value.get("source_revision")):
        errors.append(f"{label}.source_revision is required")

    records = value.get("records")
    if not isinstance(records, list) or len(records) != len(REQUIRED_ACTIVITY_IDS):
        errors.append(f"{label}.records must contain exactly five authored records")
        records = []
    activity_ids: list[Any] = []
    reward_ids: list[Any] = []
    guard_ids: list[Any] = []
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
        reward_id = record.get("reward_id")
        reward_ids.append(reward_id)
        if not _stable(reward_id):
            errors.append(f"{prefix}.reward_id must be stable lowercase text")
        retry_id = record.get("retry_guard_id")
        stale_id = record.get("stale_guard_id")
        guard_ids.extend((retry_id, stale_id))
        if retry_id != f"{activity_id}_reward_retry_g2" or stale_id != f"{activity_id}_reward_stale_g0":
            errors.append(f"{prefix}.guard IDs must be deterministic")
        if not _stable(retry_id) or not _stable(stale_id):
            errors.append(f"{prefix}.guard IDs must be stable lowercase text")
        if record.get("status") != "PASS":
            errors.append(f"{prefix}.status must be PASS")
    if tuple(activity_ids) != REQUIRED_ACTIVITY_IDS:
        errors.append(f"{label}.records must retain authored activity order")
    _unique(reward_ids, f"{label}.reward_ids", errors)
    _unique(guard_ids, f"{label}.guard_ids", errors)

    declared_digest = value.get("digest_sha256")
    if not isinstance(declared_digest, str) or len(declared_digest) != 64 or any(character not in "0123456789abcdef" for character in declared_digest):
        errors.append(f"{label}.digest_sha256 must be a lowercase SHA-256 hex digest")
    elif records and declared_digest != _digest_payload(records):
        errors.append(f"{label}.digest_sha256 does not match canonical records")

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
    parser.add_argument("digest", type=Path)
    args = parser.parse_args(argv)
    try:
        report = json.loads(args.digest.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        print(f"PLANETARY_REWARD_DIGEST_INVALID: {exc}")
        return 1
    errors = validate_digest(report)
    if errors:
        print("PLANETARY_REWARD_DIGEST_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PLANETARY_REWARD_DIGEST_VALID: detached summary digest only")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
