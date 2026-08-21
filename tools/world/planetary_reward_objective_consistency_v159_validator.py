#!/usr/bin/env python3
"""Validate detached v159 planetary reward/objective consistency evidence."""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
from pathlib import Path
from typing import Any

from tools.world.planetary_reward_objective_consistency_v158_validator import (
    _authority_digest as _v158_authority_digest,
    validate_objective_consistency as _validate_v158,
)


SCHEMA_VERSION = 159
EVIDENCE_SCOPE = "planetary_reward_objective_consistency_v159"
EVIDENCE_MODE = "detached_reward_objective_consistency_v159"
REQUIRED_WORLD_ID = "ember_moon"
REQUIRED_MANIFEST_ID = "planetary_reward_manifest_v159"
REQUIRED_PROVENANCE_ID = "planetary_reward_provenance_v159"
REQUIRED_LINEAGE_ID = "planetary_reward_lineage_v159"
REQUIRED_AUTHORITY_LINK_ID = "planetary_reward_manifest_authority_link_v159"
REQUIRED_AUTHORITY_VERSION = "authority_v159"


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


def _to_v158(value: Any) -> Any:
    if isinstance(value, dict):
        return {key: _to_v158(item) for key, item in value.items()}
    if isinstance(value, list):
        return [_to_v158(item) for item in value]
    if isinstance(value, str):
        return value.replace("v159", "v158")
    return value


def validate_objective_consistency(value: Any, label: str = "manifest") -> list[str]:
    """Return blocking errors for one v159 objective-consistency artifact."""

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
    sections = (
        ("identity", identity, {"manifest_id": REQUIRED_MANIFEST_ID, "manifest_version": "v159", "provenance_id": REQUIRED_PROVENANCE_ID, "lineage_id": REQUIRED_LINEAGE_ID}),
        ("authority_link", link, {"authority_version": REQUIRED_AUTHORITY_VERSION, "link_id": REQUIRED_AUTHORITY_LINK_ID, "manifest_id": REQUIRED_MANIFEST_ID, "provenance_id": REQUIRED_PROVENANCE_ID, "lineage_id": REQUIRED_LINEAGE_ID}),
        ("authority_reconciliation", reconciliation, {"schema_version": SCHEMA_VERSION, "authority_version": REQUIRED_AUTHORITY_VERSION, "authority_link_id": REQUIRED_AUTHORITY_LINK_ID, "manifest_id": REQUIRED_MANIFEST_ID, "manifest_version": "v159", "provenance_id": REQUIRED_PROVENANCE_ID, "lineage_id": REQUIRED_LINEAGE_ID}),
    )
    for section_name, section, expected_values in sections:
        for key, expected in expected_values.items():
            if section.get(key) != expected:
                errors.append(f"{label}.{section_name}.{key} must be {expected}")
    for index, record in enumerate(records[:5]):
        if isinstance(record, dict) and record.get("leaf_id") != f"{record.get('activity_id')}_reward_objective_consistency_leaf_v159":
            errors.append(f"{label}.records[{index}].leaf_id must be deterministic")
    digest = value.get("objective_consistency_digest_sha256")
    expected_digest = _authority_digest(identity, authority, link, reconciliation, records)
    if not isinstance(digest, str) or len(digest) != 64 or any(character not in "0123456789abcdef" for character in digest):
        errors.append(f"{label}.objective_consistency_digest_sha256 must be a lowercase SHA-256 hex digest")
    elif digest != expected_digest:
        errors.append(f"{label}.objective_consistency_digest_sha256 does not match canonical v159 payload")

    translated = _to_v158(copy.deepcopy(value))
    if isinstance(translated, dict) and isinstance(translated.get("records"), list):
        translated["schema_version"] = 158
        if isinstance(translated.get("authority_reconciliation"), dict):
            translated["authority_reconciliation"]["schema_version"] = 158
        translated["objective_consistency_digest_sha256"] = _v158_authority_digest(translated.get("identity", {}), translated.get("authority", {}), translated.get("authority_link", {}), translated.get("authority_reconciliation", {}), translated["records"])
    errors.extend(error.replace("v158", "v159") for error in _validate_v158(translated, label))
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    args = parser.parse_args(argv)
    try:
        report = json.loads(args.manifest.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        print(f"PLANETARY_REWARD_OBJECTIVE_CONSISTENCY_V159_INVALID: {exc}")
        return 1
    errors = validate_objective_consistency(report)
    if errors:
        print("PLANETARY_REWARD_OBJECTIVE_CONSISTENCY_V159_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PLANETARY_REWARD_OBJECTIVE_CONSISTENCY_V159_VALID: detached objective consistency only")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
