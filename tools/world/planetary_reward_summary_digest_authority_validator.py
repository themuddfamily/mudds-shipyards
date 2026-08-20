#!/usr/bin/env python3
"""Validate authority boundaries for a planetary reward summary digest.

The digest is owned by the existing GameFlow reward authority/store as a
detached evidence artifact.  This validator proves ownership metadata only;
it cannot write inventory, resolve objectives, or run native gameplay.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 1
EVIDENCE_SCOPE = "planetary_reward_summary_digest_authority"
EVIDENCE_MODE = "detached_reward_digest_authority"
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
    """Return blocking errors for one detached digest authority record."""

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

    authority = value.get("digest_authority")
    if not isinstance(authority, dict):
        errors.append(f"{label}.digest_authority must be an object")
    else:
        if authority.get("owner_id") != REQUIRED_REWARD_AUTHORITY:
            errors.append(f"{label}.digest_authority.owner_id must be {REQUIRED_REWARD_AUTHORITY}")
        if authority.get("store_id") != REQUIRED_REWARD_STORE:
            errors.append(f"{label}.digest_authority.store_id must be {REQUIRED_REWARD_STORE}")
        if authority.get("source") != REQUIRED_SOURCE:
            errors.append(f"{label}.digest_authority.source must be {REQUIRED_SOURCE}")
        for key in ("owns_inventory", "writes_runtime", "runs_native"):
            if authority.get(key) is not False:
                errors.append(f"{label}.digest_authority.{key} must be false")

    activities = value.get("activities")
    if not isinstance(activities, list) or len(activities) != len(REQUIRED_ACTIVITY_IDS):
        errors.append(f"{label}.activities must contain exactly five authored activities")
        activities = []
    activity_ids: list[Any] = []
    reward_ids: list[Any] = []
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
        reward_id = activity.get("reward_id")
        reward_ids.append(reward_id)
        if not _stable(reward_id):
            errors.append(f"{prefix}.reward_id must be stable lowercase text")
        if activity.get("reward_authority_id") != REQUIRED_REWARD_AUTHORITY:
            errors.append(f"{prefix}.reward_authority_id must be {REQUIRED_REWARD_AUTHORITY}")
        if activity.get("reward_store_id") != REQUIRED_REWARD_STORE:
            errors.append(f"{prefix}.reward_store_id must be {REQUIRED_REWARD_STORE}")
        if activity.get("digest_included_once") is not True:
            errors.append(f"{prefix}.digest_included_once must be true")
    if tuple(activity_ids) != REQUIRED_ACTIVITY_IDS:
        errors.append(f"{label}.activities must retain authored activity order")
    _unique(reward_ids, f"{label}.reward_ids", errors)

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
        print(f"PLANETARY_REWARD_DIGEST_AUTHORITY_INVALID: {exc}")
        return 1
    errors = validate_authority(report)
    if errors:
        print("PLANETARY_REWARD_DIGEST_AUTHORITY_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PLANETARY_REWARD_DIGEST_AUTHORITY_VALID: detached authority metadata only")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
