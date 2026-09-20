#!/usr/bin/env python3
"""Validate v119-v1019 planetary reward/objective consistency evidence.

This replaces 901 per-version modules that were byte-identical apart from the
version string, each importing its predecessor so that validating one document
recursed 900 frames deep. The contract never changed across those versions: a
document names its schema version in six places, carries a canonical SHA-256
digest over its identity/authority/link/reconciliation/records payload, gives
every record a deterministic leaf id, and must also satisfy the surviving
`planetary_reward_consistency_state_v118_validator` once translated down.

Like `tools/audio/audio_cleanup_evidence_state_validator.py`, this implements
the family's contract across its historical version range rather than
reproducing each retired module. It validates detached evidence documents only;
it makes no claim about the game, a build, or any human or native gate.
"""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
from pathlib import Path
from typing import Any

from tools.world.planetary_reward_consistency_state_v118_validator import (
    _authority_digest as _state_authority_digest,
    validate_consistency_state as _validate_state,
)

SUPPORTED_VERSIONS = range(119, 1020)
BASE_VERSION = 118
REQUIRED_WORLD_ID = "ember_moon"
DIGEST_FIELD = "objective_consistency_digest_sha256"
_IDENTITY_KEYS = ("manifest_id", "manifest_version", "provenance_id", "lineage_id", "evidence_ref")
_AUTHORITY_KEYS = ("reward_authority_id", "reward_store_id", "authority_scope", "source")
_RECORD_KEYS = (
    "activity_id",
    "manifest_id",
    "provenance_id",
    "activity_authority_id",
    "reward_authority_id",
    "reward_store_id",
    "reward_id",
    "leaf_id",
    "evidence_ref",
    "status",
)


def _authority_digest(
    version: int,
    identity: dict[str, Any],
    authority: dict[str, Any],
    link: dict[str, Any],
    reconciliation: dict[str, Any],
    records: list[dict[str, Any]],
) -> str:
    """Canonical digest over the payload a document of `version` must carry."""
    payload = {
        "schema_version": version,
        "authority_version": f"authority_v{version}",
        "identity": {key: identity.get(key) for key in _IDENTITY_KEYS},
        "authority": {key: authority.get(key) for key in _AUTHORITY_KEYS},
        "authority_link": link,
        "reconciliation": reconciliation,
        "records": [
            {key: record.get(key) for key in _RECORD_KEYS}
            for record in records
            if isinstance(record, dict)
        ],
    }
    encoded = json.dumps(payload, ensure_ascii=True, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(encoded.encode("utf-8")).hexdigest()


def _renamed(value: Any, old: str, new: str) -> Any:
    if isinstance(value, dict):
        return {key: _renamed(item, old, new) for key, item in value.items()}
    if isinstance(value, list):
        return [_renamed(item, old, new) for item in value]
    if isinstance(value, str):
        return value.replace(old, new).replace("objective_consistency", "consistency_state")
    return value


def document_version(value: Any) -> int | None:
    """The schema version a document declares, or None when it declares none."""
    if isinstance(value, dict) and isinstance(value.get("schema_version"), int):
        return value["schema_version"]
    return None


def validate_objective_consistency(
    value: Any,
    label: str = "manifest",
    *,
    schema_version: int | None = None,
) -> list[str]:
    """Return blocking errors for one objective-consistency artifact.

    `schema_version` pins the expected version; by default the document's own
    declared version is used, and must fall inside the supported range.
    """
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    version = schema_version if schema_version is not None else document_version(value)
    if version is None or version not in SUPPORTED_VERSIONS:
        return [f"{label}.schema_version must be an integer between 119 and 1019"]

    errors: list[str] = []
    expected_top = (
        ("schema_version", version),
        ("evidence_scope", f"planetary_reward_objective_consistency_v{version}"),
        ("evidence_mode", f"detached_reward_objective_consistency_v{version}"),
    )
    for key, expected in expected_top:
        if value.get(key) != expected:
            errors.append(f"{label}.{key} must be {expected}")
    if value.get("world_id") != REQUIRED_WORLD_ID:
        errors.append(f"{label}.world_id must be {REQUIRED_WORLD_ID}")

    identity = value.get("identity") if isinstance(value.get("identity"), dict) else {}
    authority = value.get("authority") if isinstance(value.get("authority"), dict) else {}
    link = value.get("authority_link") if isinstance(value.get("authority_link"), dict) else {}
    reconciliation = (
        value.get("authority_reconciliation")
        if isinstance(value.get("authority_reconciliation"), dict)
        else {}
    )
    records = value.get("records") if isinstance(value.get("records"), list) else []

    manifest_id = f"planetary_reward_manifest_v{version}"
    provenance_id = f"planetary_reward_provenance_v{version}"
    lineage_id = f"planetary_reward_lineage_v{version}"
    link_id = f"planetary_reward_manifest_authority_link_v{version}"
    authority_version = f"authority_v{version}"
    sections = (
        (
            "identity",
            identity,
            {
                "manifest_id": manifest_id,
                "manifest_version": f"v{version}",
                "provenance_id": provenance_id,
                "lineage_id": lineage_id,
            },
        ),
        (
            "authority_link",
            link,
            {
                "authority_version": authority_version,
                "link_id": link_id,
                "manifest_id": manifest_id,
                "provenance_id": provenance_id,
                "lineage_id": lineage_id,
            },
        ),
        (
            "authority_reconciliation",
            reconciliation,
            {
                "schema_version": version,
                "authority_version": authority_version,
                "authority_link_id": link_id,
                "manifest_id": manifest_id,
                "manifest_version": f"v{version}",
                "provenance_id": provenance_id,
                "lineage_id": lineage_id,
            },
        ),
    )
    for section_name, section, expected_values in sections:
        for key, expected in expected_values.items():
            if section.get(key) != expected:
                errors.append(f"{label}.{section_name}.{key} must be {expected}")

    for index, record in enumerate(records[:5]):
        if not isinstance(record, dict):
            continue
        leaf = f"{record.get('activity_id')}_reward_objective_consistency_leaf_v{version}"
        if record.get("leaf_id") != leaf:
            errors.append(f"{label}.records[{index}].leaf_id must be deterministic")

    digest = value.get(DIGEST_FIELD)
    expected_digest = _authority_digest(version, identity, authority, link, reconciliation, records)
    if not isinstance(digest, str) or len(digest) != 64 or any(c not in "0123456789abcdef" for c in digest):
        errors.append(f"{label}.{DIGEST_FIELD} must be a lowercase SHA-256 hex digest")
    elif digest != expected_digest:
        errors.append(f"{label}.{DIGEST_FIELD} does not match canonical v{version} payload")

    translated = _renamed(copy.deepcopy(value), f"v{version}", f"v{BASE_VERSION}")
    if isinstance(translated, dict) and isinstance(translated.get("records"), list):
        translated["schema_version"] = BASE_VERSION
        if isinstance(translated.get("authority_reconciliation"), dict):
            translated["authority_reconciliation"]["schema_version"] = BASE_VERSION
        translated["consistency_state_digest_sha256"] = _state_authority_digest(
            translated.get("identity", {}),
            translated.get("authority", {}),
            translated.get("authority_link", {}),
            translated.get("authority_reconciliation", {}),
            translated["records"],
        )
        errors.extend(
            error.replace(f"v{BASE_VERSION}", f"v{version}")
            for error in _validate_state(translated, label)
        )
    return errors


def validate(path: str | Path) -> list[str]:
    try:
        return validate_objective_consistency(json.loads(Path(path).read_text(encoding="utf-8")))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"unreadable: {exc}"]


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    parser.add_argument("--schema-version", type=int, default=None)
    args = parser.parse_args(argv)
    try:
        report = json.loads(args.manifest.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        print(f"PLANETARY_REWARD_OBJECTIVE_CONSISTENCY_INVALID: {exc}")
        return 1
    errors = validate_objective_consistency(report, schema_version=args.schema_version)
    if errors:
        print("PLANETARY_REWARD_OBJECTIVE_CONSISTENCY_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PLANETARY_REWARD_OBJECTIVE_CONSISTENCY_VALID: detached objective consistency only")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
