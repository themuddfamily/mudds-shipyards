#!/usr/bin/env python3
"""Validate v14 authority-scoped snapshot identity/count evidence."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 14
EVIDENCE_SCOPE = "network_snapshot_manifest_identity_count_authority_v14"
EVIDENCE_MODE = "detached_contract_fixture"
POLICY_VERSION = "network_replication_interest_authority_v1"
AUTHORITY = "server"
SHA256 = re.compile(r"^[0-9a-f]{64}$")


def _sequence(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value >= 0


def _digest(value: Any) -> bool:
    return isinstance(value, str) and SHA256.fullmatch(value) is not None


def _anchor_digest(anchor: dict[str, Any]) -> str:
    return hashlib.sha256(f"{AUTHORITY}|{anchor.get('identity_id')}|{anchor.get('sequence')}|{anchor.get('digest')}".encode("utf-8")).hexdigest()


def validate_identity_counts(report: Any, label: str = "identity_counts") -> list[str]:
    """Return anchor, identity, count, and no-mutation errors."""

    errors: list[str] = []
    if not isinstance(report, dict):
        return [f"{label} must be an object"]
    for key, expected in (
        ("schema_version", SCHEMA_VERSION),
        ("evidence_scope", EVIDENCE_SCOPE),
        ("evidence_mode", EVIDENCE_MODE),
        ("policy_version", POLICY_VERSION),
        ("authority", AUTHORITY),
    ):
        if report.get(key) != expected:
            errors.append(f"{label}.{key} must be {expected}")
    for key in ("native_claims", "uses_live_network"):
        if report.get(key) is not False:
            errors.append(f"{label}.{key} must be false")
    for key in ("snapshot_detached", "no_mutation_guarantee"):
        if report.get(key) is not True:
            errors.append(f"{label}.{key} must be true")

    anchor = report.get("manifest_identity")
    if not isinstance(anchor, dict):
        errors.append(f"{label}.manifest_identity must be an object")
        anchor = {}
    if anchor.get("authority") != AUTHORITY:
        errors.append(f"{label}.manifest_identity.authority must be {AUTHORITY}")
    if not isinstance(anchor.get("identity_id"), str) or not anchor.get("identity_id"):
        errors.append(f"{label}.manifest_identity.identity_id must be non-empty")
    if not _sequence(anchor.get("sequence")):
        errors.append(f"{label}.manifest_identity.sequence must be non-negative")
    if not _digest(anchor.get("digest")):
        errors.append(f"{label}.manifest_identity.digest must be lowercase SHA-256")
    anchor_digest = anchor.get("identity_digest")
    if not _digest(anchor_digest):
        errors.append(f"{label}.manifest_identity.identity_digest must be lowercase SHA-256")
    elif anchor_digest != _anchor_digest(anchor):
        errors.append(f"{label}.manifest_identity.identity_digest must anchor identity")

    identities = report.get("identities")
    if not isinstance(identities, list):
        errors.append(f"{label}.identities must be an array")
        identities = []
    identity_ids: set[str] = set()
    reconciled_count = 0
    mutation_count = 0
    for index, identity in enumerate(identities):
        prefix = f"{label}.identities[{index}]"
        if not isinstance(identity, dict):
            errors.append(f"{prefix} must be an object")
            continue
        identity_id = identity.get("identity_id")
        if not isinstance(identity_id, str) or not identity_id:
            errors.append(f"{prefix}.identity_id must be non-empty")
        elif identity_id in identity_ids:
            errors.append(f"{prefix}.identity_id must be unique")
        else:
            identity_ids.add(identity_id)
        if identity.get("authority") != AUTHORITY:
            errors.append(f"{prefix}.authority must be {AUTHORITY}")
        if identity.get("manifest_identity_id") != anchor.get("identity_id"):
            errors.append(f"{prefix}.manifest_identity_id must match anchor")
        if identity.get("identity_digest") != anchor_digest:
            errors.append(f"{prefix}.identity_digest must match anchor")
        if identity.get("sequence") != anchor.get("sequence"):
            errors.append(f"{prefix}.sequence must match anchor")
        if not _digest(identity.get("digest")):
            errors.append(f"{prefix}.digest must be lowercase SHA-256")
        if identity.get("reconciled") is not True:
            errors.append(f"{prefix}.reconciled must be true")
        else:
            reconciled_count += 1
        if identity.get("mutation_fields") != [] or identity.get("state_changed") is not False:
            mutation_count += 1
            errors.append(f"{prefix} must have no mutation")

    counts = report.get("counts")
    if not isinstance(counts, dict):
        errors.append(f"{label}.counts must be an object")
    else:
        expected = {"records": len(identities), "unique": len(identity_ids), "reconciled": reconciled_count, "mutations": mutation_count}
        for key, value in expected.items():
            if counts.get(key) != value:
                errors.append(f"{label}.counts.{key} must match identity records")
        if counts.get("mutations") != 0:
            errors.append(f"{label}.counts.mutations must be zero")
    return errors


def validate_identity_counts_file(report_path: Path) -> list[str]:
    try:
        report = json.loads(report_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"unable to read {report_path}: {exc}"]
    return validate_identity_counts(report, str(report_path))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("identity_counts", type=Path)
    args = parser.parse_args()
    errors = validate_identity_counts_file(args.identity_counts)
    if errors:
        print("NETWORK_SNAPSHOT_MANIFEST_IDENTITY_COUNT_AUTHORITY_V14_INVALID")
        for error in errors:
            print(f"- {error}")
        return 1
    print("NETWORK_SNAPSHOT_MANIFEST_IDENTITY_COUNT_AUTHORITY_V14_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
