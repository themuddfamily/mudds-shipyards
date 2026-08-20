#!/usr/bin/env python3
"""Validate detached v51 planetary reward release/version authority evidence."""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
from pathlib import Path
from typing import Any

from tools.world.planetary_reward_versioned_authority_reconciliation_v50_validator import (
    _authority_digest as _v50_authority_digest,
    validate_authority_reconciliation as _validate_v50,
)


SCHEMA_VERSION = 51
EVIDENCE_SCOPE = "planetary_reward_release_version_authority_reconciliation_v51"
EVIDENCE_MODE = "detached_reward_release_version_authority_reconciliation_v51"
REQUIRED_WORLD_ID = "ember_moon"
REQUIRED_MANIFEST_ID = "planetary_reward_manifest_v51"
REQUIRED_PROVENANCE_ID = "planetary_reward_provenance_v51"
REQUIRED_LINEAGE_ID = "planetary_reward_lineage_v51"
REQUIRED_REWARD_AUTHORITY = "game_flow_reward_authority"
REQUIRED_REWARD_STORE = "game_flow_reward_store"
REQUIRED_AUTHORITY_SCOPE = "planetary_reward_release_version_authority_reconciliation"
REQUIRED_AUTHORITY_LINK_ID = "planetary_reward_manifest_authority_link_v51"
REQUIRED_AUTHORITY_VERSION = "authority_v51"


def _authority_digest(identity: dict[str, Any], authority: dict[str, Any], link: dict[str, Any], reconciliation: dict[str, Any], records: list[dict[str, Any]]) -> str:
    payload = {
        "schema_version": SCHEMA_VERSION,
        "authority_version": REQUIRED_AUTHORITY_VERSION,
        "identity": {key: identity.get(key) for key in ("manifest_id", "manifest_version", "provenance_id", "lineage_id", "evidence_ref")},
        "authority": {key: authority.get(key) for key in ("reward_authority_id", "reward_store_id", "authority_scope", "source")},
        "authority_link": link,
        "reconciliation": reconciliation,
        "records": [{key: record.get(key) for key in ("activity_id", "manifest_id", "provenance_id", "activity_authority_id", "reward_authority_id", "reward_store_id", "reward_id", "leaf_id", "evidence_ref", "status")} for record in records if isinstance(record, dict)],
    }
    return hashlib.sha256(json.dumps(payload, ensure_ascii=True, sort_keys=True, separators=(",", ":")).encode("utf-8")).hexdigest()


def _replace_version(value: Any) -> Any:
    if isinstance(value, dict):
        return {key: _replace_version(item) for key, item in value.items()}
    if isinstance(value, list):
        return [_replace_version(item) for item in value]
    if isinstance(value, str):
        return value.replace("v51", "v50")
    return value


def _to_v50(value: Any) -> Any:
    translated = _replace_version(value)
    if isinstance(translated, dict):
        replacements = {
            "planetary_reward_release_version_authority_reconciliation_v50": "planetary_reward_versioned_authority_reconciliation_v50",
            "detached_reward_release_version_authority_reconciliation_v50": "detached_reward_versioned_authority_reconciliation_v50",
            "planetary_reward_release_version_authority_reconciliation": "planetary_reward_versioned_authority_reconciliation",
            "reward_release_version_authority_leaf_v50": "reward_versioned_authority_leaf_v50",
        }

        def normalize(item: Any) -> Any:
            if isinstance(item, dict):
                return {key: normalize(child) for key, child in item.items()}
            if isinstance(item, list):
                return [normalize(child) for child in item]
            if isinstance(item, str):
                for source, target in replacements.items():
                    item = item.replace(source, target)
            return item

        translated = normalize(translated)
    return translated


def validate_release_version_authority(value: Any, label: str = "manifest") -> list[str]:
    """Return blocking errors for one v51 release/version authority artifact."""

    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    for key, expected in (("schema_version", SCHEMA_VERSION), ("evidence_scope", EVIDENCE_SCOPE), ("evidence_mode", EVIDENCE_MODE)):
        if value.get(key) != expected:
            errors.append(f"{label}.{key} must be {expected}")
    if value.get("world_id") != REQUIRED_WORLD_ID:
        errors.append(f"{label}.world_id must be {REQUIRED_WORLD_ID}")
    identity = value.get("identity") if isinstance(value.get("identity"), dict) else {}
    authority = value.get("authority") if isinstance(value.get("authority"), dict) else {}
    link = value.get("authority_link") if isinstance(value.get("authority_link"), dict) else {}
    reconciliation = value.get("authority_reconciliation") if isinstance(value.get("authority_reconciliation"), dict) else {}
    records = value.get("records") if isinstance(value.get("records"), list) else []
    for section, expected_values in (
        (identity, {"manifest_id": REQUIRED_MANIFEST_ID, "manifest_version": "v51", "provenance_id": REQUIRED_PROVENANCE_ID, "lineage_id": REQUIRED_LINEAGE_ID}),
        (link, {"authority_version": REQUIRED_AUTHORITY_VERSION, "link_id": REQUIRED_AUTHORITY_LINK_ID, "manifest_id": REQUIRED_MANIFEST_ID, "provenance_id": REQUIRED_PROVENANCE_ID, "lineage_id": REQUIRED_LINEAGE_ID}),
        (reconciliation, {"schema_version": SCHEMA_VERSION, "authority_version": REQUIRED_AUTHORITY_VERSION, "authority_link_id": REQUIRED_AUTHORITY_LINK_ID, "manifest_id": REQUIRED_MANIFEST_ID, "manifest_version": "v51", "provenance_id": REQUIRED_PROVENANCE_ID, "lineage_id": REQUIRED_LINEAGE_ID}),
    ):
        for key, expected in expected_values.items():
            if section.get(key) != expected:
                section_name = "identity" if section is identity else "authority_link" if section is link else "authority_reconciliation"
                errors.append(f"{label}.{section_name}.{key} must be {expected}")
    for index, record in enumerate(records[:5]):
        if isinstance(record, dict) and record.get("leaf_id") != f"{record.get('activity_id')}_reward_release_version_authority_leaf_v51":
            errors.append(f"{label}.records[{index}].leaf_id must be deterministic")
    digest = value.get("release_version_authority_digest_sha256")
    expected_digest = _authority_digest(identity, authority, link, reconciliation, records)
    if not isinstance(digest, str) or len(digest) != 64 or any(character not in "0123456789abcdef" for character in digest):
        errors.append(f"{label}.release_version_authority_digest_sha256 must be a lowercase SHA-256 hex digest")
    elif digest != expected_digest:
        errors.append(f"{label}.release_version_authority_digest_sha256 does not match canonical v51 payload")

    translated = _to_v50(copy.deepcopy(value))
    if isinstance(translated, dict) and isinstance(translated.get("records"), list):
        translated["schema_version"] = 50
        if isinstance(translated.get("authority_reconciliation"), dict):
            translated["authority_reconciliation"]["schema_version"] = 50
        translated["versioned_authority_digest_sha256"] = _v50_authority_digest(translated.get("identity", {}), translated.get("authority", {}), translated.get("authority_link", {}), translated.get("authority_reconciliation", {}), translated["records"])
    errors.extend(error.replace("v50", "v51") for error in _validate_v50(translated, label))
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    args = parser.parse_args(argv)
    try:
        report = json.loads(args.manifest.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        print(f"PLANETARY_REWARD_RELEASE_VERSION_AUTHORITY_V51_INVALID: {exc}")
        return 1
    errors = validate_release_version_authority(report)
    if errors:
        print("PLANETARY_REWARD_RELEASE_VERSION_AUTHORITY_V51_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PLANETARY_REWARD_RELEASE_VERSION_AUTHORITY_V51_VALID: detached release/version reconciliation only")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
