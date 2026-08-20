#!/usr/bin/env python3
"""Validate detached v60 planetary reward attestation/source reconciliation evidence."""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
from pathlib import Path
from typing import Any

from tools.world.planetary_reward_source_channel_release_v59_validator import (
    _authority_digest as _v59_authority_digest,
    validate_source_channel_release as _validate_v59,
)


SCHEMA_VERSION = 60
EVIDENCE_SCOPE = "planetary_reward_attestation_source_reconciliation_v60"
EVIDENCE_MODE = "detached_reward_attestation_source_reconciliation_v60"
REQUIRED_WORLD_ID = "ember_moon"
REQUIRED_MANIFEST_ID = "planetary_reward_manifest_v60"
REQUIRED_PROVENANCE_ID = "planetary_reward_provenance_v60"
REQUIRED_LINEAGE_ID = "planetary_reward_lineage_v60"
REQUIRED_REWARD_AUTHORITY = "game_flow_reward_authority"
REQUIRED_REWARD_STORE = "game_flow_reward_store"
REQUIRED_AUTHORITY_SCOPE = "planetary_reward_attestation_source_reconciliation"
REQUIRED_AUTHORITY_LINK_ID = "planetary_reward_manifest_authority_link_v60"
REQUIRED_AUTHORITY_VERSION = "authority_v60"


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


def _to_v59(value: Any) -> Any:
    if isinstance(value, dict):
        return {key: _to_v59(item) for key, item in value.items()}
    if isinstance(value, list):
        return [_to_v59(item) for item in value]
    if isinstance(value, str):
        value = value.replace("v60", "v59")
        value = value.replace("attestation_source_reconciliation_v59", "source_channel_release_v59")
        value = value.replace("attestation_source_reconciliation", "source_channel_release")
        value = value.replace("attestation_source_channel_release", "source_channel_release")
        return value
    return value


def validate_attestation_source_reconciliation(value: Any, label: str = "manifest") -> list[str]:
    """Return blocking errors for one v60 attestation/source reconciliation artifact."""

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
        ("identity", identity, {"manifest_id": REQUIRED_MANIFEST_ID, "manifest_version": "v60", "provenance_id": REQUIRED_PROVENANCE_ID, "lineage_id": REQUIRED_LINEAGE_ID}),
        ("authority_link", link, {"authority_version": REQUIRED_AUTHORITY_VERSION, "link_id": REQUIRED_AUTHORITY_LINK_ID, "manifest_id": REQUIRED_MANIFEST_ID, "provenance_id": REQUIRED_PROVENANCE_ID, "lineage_id": REQUIRED_LINEAGE_ID}),
        ("authority_reconciliation", reconciliation, {"schema_version": SCHEMA_VERSION, "authority_version": REQUIRED_AUTHORITY_VERSION, "authority_link_id": REQUIRED_AUTHORITY_LINK_ID, "manifest_id": REQUIRED_MANIFEST_ID, "manifest_version": "v60", "provenance_id": REQUIRED_PROVENANCE_ID, "lineage_id": REQUIRED_LINEAGE_ID}),
    )
    for section_name, section, expected_values in sections:
        for key, expected in expected_values.items():
            if section.get(key) != expected:
                errors.append(f"{label}.{section_name}.{key} must be {expected}")
    for index, record in enumerate(records[:5]):
        if isinstance(record, dict) and record.get("leaf_id") != f"{record.get('activity_id')}_reward_attestation_source_reconciliation_leaf_v60":
            errors.append(f"{label}.records[{index}].leaf_id must be deterministic")
    digest = value.get("attestation_source_reconciliation_digest_sha256")
    expected_digest = _authority_digest(identity, authority, link, reconciliation, records)
    if not isinstance(digest, str) or len(digest) != 64 or any(character not in "0123456789abcdef" for character in digest):
        errors.append(f"{label}.attestation_source_reconciliation_digest_sha256 must be a lowercase SHA-256 hex digest")
    elif digest != expected_digest:
        errors.append(f"{label}.attestation_source_reconciliation_digest_sha256 does not match canonical v60 payload")

    translated = _to_v59(copy.deepcopy(value))
    if isinstance(translated, dict) and isinstance(translated.get("records"), list):
        translated["schema_version"] = 59
        if isinstance(translated.get("authority_reconciliation"), dict):
            translated["authority_reconciliation"]["schema_version"] = 59
        translated["source_channel_release_digest_sha256"] = _v59_authority_digest(translated.get("identity", {}), translated.get("authority", {}), translated.get("authority_link", {}), translated.get("authority_reconciliation", {}), translated["records"])
    errors.extend(error.replace("v59", "v60") for error in _validate_v59(translated, label))
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    args = parser.parse_args(argv)
    try:
        report = json.loads(args.manifest.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        print(f"PLANETARY_REWARD_ATTESTATION_SOURCE_RECONCILIATION_V60_INVALID: {exc}")
        return 1
    errors = validate_attestation_source_reconciliation(report)
    if errors:
        print("PLANETARY_REWARD_ATTESTATION_SOURCE_RECONCILIATION_V60_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PLANETARY_REWARD_ATTESTATION_SOURCE_RECONCILIATION_V60_VALID: detached attestation/source reconciliation only")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
