#!/usr/bin/env python3
"""Validate detached v74 planetary reward source/closure evidence."""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
from pathlib import Path
from typing import Any

from tools.world.planetary_reward_audit_lineage_v73_validator import (
    _authority_digest as _v73_authority_digest,
    validate_audit_lineage as _validate_v73,
)


SCHEMA_VERSION = 74
EVIDENCE_SCOPE = "planetary_reward_source_closure_v74"
EVIDENCE_MODE = "detached_reward_source_closure_v74"
REQUIRED_WORLD_ID = "ember_moon"
REQUIRED_MANIFEST_ID = "planetary_reward_manifest_v74"
REQUIRED_PROVENANCE_ID = "planetary_reward_provenance_v74"
REQUIRED_LINEAGE_ID = "planetary_reward_lineage_v74"
REQUIRED_REWARD_AUTHORITY = "game_flow_reward_authority"
REQUIRED_REWARD_STORE = "game_flow_reward_store"
REQUIRED_AUTHORITY_SCOPE = "planetary_reward_source_closure"
REQUIRED_AUTHORITY_LINK_ID = "planetary_reward_manifest_authority_link_v74"
REQUIRED_AUTHORITY_VERSION = "authority_v74"


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


def _to_v73(value: Any) -> Any:
    if isinstance(value, dict):
        return {key: _to_v73(item) for key, item in value.items()}
    if isinstance(value, list):
        return [_to_v73(item) for item in value]
    if isinstance(value, str):
        value = value.replace("v74", "v73")
        return value.replace("source_closure", "audit_lineage")
    return value


def validate_source_closure(value: Any, label: str = "manifest") -> list[str]:
    """Return blocking errors for one v74 source/closure artifact."""

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
        ("identity", identity, {"manifest_id": REQUIRED_MANIFEST_ID, "manifest_version": "v74", "provenance_id": REQUIRED_PROVENANCE_ID, "lineage_id": REQUIRED_LINEAGE_ID}),
        ("authority_link", link, {"authority_version": REQUIRED_AUTHORITY_VERSION, "link_id": REQUIRED_AUTHORITY_LINK_ID, "manifest_id": REQUIRED_MANIFEST_ID, "provenance_id": REQUIRED_PROVENANCE_ID, "lineage_id": REQUIRED_LINEAGE_ID}),
        ("authority_reconciliation", reconciliation, {"schema_version": SCHEMA_VERSION, "authority_version": REQUIRED_AUTHORITY_VERSION, "authority_link_id": REQUIRED_AUTHORITY_LINK_ID, "manifest_id": REQUIRED_MANIFEST_ID, "manifest_version": "v74", "provenance_id": REQUIRED_PROVENANCE_ID, "lineage_id": REQUIRED_LINEAGE_ID}),
    )
    for section_name, section, expected_values in sections:
        for key, expected in expected_values.items():
            if section.get(key) != expected:
                errors.append(f"{label}.{section_name}.{key} must be {expected}")
    for index, record in enumerate(records[:5]):
        if isinstance(record, dict) and record.get("leaf_id") != f"{record.get('activity_id')}_reward_source_closure_leaf_v74":
            errors.append(f"{label}.records[{index}].leaf_id must be deterministic")
    digest = value.get("source_closure_digest_sha256")
    expected_digest = _authority_digest(identity, authority, link, reconciliation, records)
    if not isinstance(digest, str) or len(digest) != 64 or any(character not in "0123456789abcdef" for character in digest):
        errors.append(f"{label}.source_closure_digest_sha256 must be a lowercase SHA-256 hex digest")
    elif digest != expected_digest:
        errors.append(f"{label}.source_closure_digest_sha256 does not match canonical v74 payload")

    translated = _to_v73(copy.deepcopy(value))
    if isinstance(translated, dict) and isinstance(translated.get("records"), list):
        translated["schema_version"] = 73
        if isinstance(translated.get("authority_reconciliation"), dict):
            translated["authority_reconciliation"]["schema_version"] = 73
        translated["audit_lineage_digest_sha256"] = _v73_authority_digest(translated.get("identity", {}), translated.get("authority", {}), translated.get("authority_link", {}), translated.get("authority_reconciliation", {}), translated["records"])
    errors.extend(error.replace("v73", "v74") for error in _validate_v73(translated, label))
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    args = parser.parse_args(argv)
    try:
        report = json.loads(args.manifest.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        print(f"PLANETARY_REWARD_SOURCE_CLOSURE_V74_INVALID: {exc}")
        return 1
    errors = validate_source_closure(report)
    if errors:
        print("PLANETARY_REWARD_SOURCE_CLOSURE_V74_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PLANETARY_REWARD_SOURCE_CLOSURE_V74_VALID: detached source/closure only")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
